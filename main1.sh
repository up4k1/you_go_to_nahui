# Запрос ввода данных пользователя
if ! command -v docker &>/dev/null; then
    echo "Docker не найден. Устанавливаю Docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Проверка наличия Docker Compose
if ! command -v docker-compose &>/dev/null; then
    echo "Docker Compose не найден. Устанавливаю Docker Compose..."
    sudo curl -k -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

read -p "Enter your domain (e.g., yourdomain.com): " DOMAIN
read -p "Enter your email for Let's Encrypt: " EMAIL
read -p "Enter your YOURLS admin username: " YOURLS_ADMIN_USER
read -p "Enter your YOURLS admin password: " YOURLS_ADMIN_PASS
echo
read -p "Enter your MySQL root password: " MYSQL_ROOT_PASS
echo
read -p "Enter your YOURLS database password: " YOURLS_DB_PASS
echo

# Создание Dockerfile для Nginx
cat <<EOF >Dockerfile
FROM nginx:alpine
RUN apk add --no-cache certbot
COPY nginx.conf /etc/nginx/nginx.conf
CMD ["nginx", "-g", "daemon off;"]
EOF

# Создание начальной конфигурации Nginx
cat <<EOF >nginx.conf
worker_processes 1;
events { worker_connections 1024; }
http {
    sendfile on;
    server {
        listen 80;
        server_name $DOMAIN;
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        location / {
            return 301 https://\$host\$request_uri;
        }
    }
}
EOF

# Создание docker-compose.yml
cat <<EOF >docker-compose.yml
version: '3.8'
services:
  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASS
      MYSQL_DATABASE: yourls
      MYSQL_USER: yourls
      MYSQL_PASSWORD: $YOURLS_DB_PASS
    volumes:
      - db_data:/var/lib/mysql
    restart: always
    
  yourls:
    image: yourls
    depends_on:
      - db
    environment:
      YOURLS_DB_HOST: db
      YOURLS_DB_USER: yourls
      YOURLS_DB_PASS: $YOURLS_DB_PASS
      YOURLS_DB_NAME: yourls
      YOURLS_SITE: https://$DOMAIN
      YOURLS_USER: $YOURLS_ADMIN_USER
      YOURLS_PASS: $YOURLS_ADMIN_PASS
    volumes:
      - yourls_data:/var/www/html
      - ./plugins:/var/www/html/user/plugins
      - ./Ydata:/var/www/html/user
    restart: always
    
  nginx:
    build: .
    depends_on:
      - yourls
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./certbot_data:/var/www/certbot
      - ./certbot_certs:/etc/letsencrypt
    ports:
      - '80:80'
      - '443:443'
    restart: always
volumes:
  db_data:
  yourls_data:
  certbot_data:
  certbot_certs:
EOF

# Запуск Docker Compose
docker-compose up -d

# Пауза для запуска Nginx
sleep 30

# Получение SSL-сертификатов с Certbot
docker-compose exec nginx certbot certonly --webroot -w /var/www/certbot -d $DOMAIN --email $EMAIL --agree-tos --no-eff-email --keep-until-expiring --quiet

cat <<EOF >nginx-ssl.conf
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://yourls:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Получение ID контейнера Nginx
NGINX_CONTAINER_ID=$(docker-compose ps -q nginx)

# Копирование новой конфигурации в контейнер и перезапуск Nginx
docker cp nginx-ssl.conf $NGINX_CONTAINER_ID:/etc/nginx/conf.d/default.conf
docker-compose restart nginx
YOURLS_CONTAINER_ID=$(docker-compose ps -q yourls)
if [ ! -z "$YOURLS_CONTAINER_ID" ]; then
    docker exec $YOURLS_CONTAINER_ID bash -c "echo 'ServerName $DOMAIN' >> /etc/apache2/apache2.conf && apachectl restart"
fi
sed -i '/http {/a \ \ \ \ include /etc/nginx/conf.d/*.conf;' nginx.conf
# Получение ID контейнера YOURLS
YOURLS_CONTAINER_ID=$(docker-compose ps -q yourls)

# Изменение файла config.php внутри контейнера
if [ ! -z "$YOURLS_CONTAINER_ID" ]; then
    docker exec $YOURLS_CONTAINER_ID bash -c "sed -i \"s/define( 'YOURLS_UNIQUE_URLS', getenv('YOURLS_UNIQUE_URLS') === false /define( 'YOURLS_UNIQUE_URLS', getenv('YOURLS_UNIQUE_URLS') === true /\" /var/www/html/user/config.php"
fi




# Перезапуск Docker Compose для применения изменений
docker-compose restart nginx
# ... предыдущие шаги скрипта ...

# Настройка cron job для автоматического обновления сертификатов
CURRENT_DIR=$(pwd)
(crontab -l 2>/dev/null; echo "0 */12 * * * cd $CURRENT_DIR && /usr/local/bin/docker-compose exec -T nginx certbot renew && /usr/local/bin/docker-compose restart nginx") | crontab -
# Скачивание файла ssl.sh из удаленного репозитория
echo "Скачиваю ssl.sh..."
curl -L "https://raw.githubusercontent.com/up4k1/you_go_to_nahui/main/ssl.sh" -o ssl.sh

# Назначение прав на выполнение для ssl.sh
echo "Устанавливаю права на выполнение для ssl.sh..."
chmod +x ssl.sh

echo "Файл ssl.sh скачан и готов к использованию."
