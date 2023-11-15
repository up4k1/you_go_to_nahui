#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для проверки статуса выполнения команды
check_status() {
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Успех.${NC}"
  else
    echo -e "${RED}Ошибка. Процесс остановлен.${NC}"
    exit 1
  fi
}

# Проверка и установка Docker
echo -e "${YELLOW}Проверка и установка Docker...${NC}"
if ! [ -x "$(command -v docker)" ]; then
  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt update
  sudo apt install -y docker-ce
fi
check_status

# Проверка и установка Docker Compose
echo -e "${YELLOW}Проверка и установка Docker Compose...${NC}"
if ! [ -x "$(command -v docker-compose)" ]; then
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi
check_status

# Запрос основной информации от пользователя
echo -e "${YELLOW}Запрос основной информации...${NC}"
read -p "Введите имя домена (например, short.ru): " DOMAIN
read -p "Введите имя пользователя для YOURLS: " YOURLS_USER
read -p "Введите пароль для YOURLS: " YOURLS_PASS
read -p "Введите email для Let's Encrypt: " LETSENCRYPT_EMAIL
read -p "Введите пароль для MySQL: " MYSQL_ROOT_PASSWORD
check_status

# Создание файла .env для YOURLS
echo -e "${YELLOW}Создание файла .env для YOURLS...${NC}"
cat > .env <<EOF
YOURLS_SITE=https://$DOMAIN
YOURLS_USER=$YOURLS_USER
YOURLS_PASS=$YOURLS_PASS
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=yourls
EOF
check_status

# Создание файла docker-compose.yml
echo -e "${YELLOW}Создание файла docker-compose.yml...${NC}"
cat > docker-compose.yml <<EOF
version: '3'

services:
  yourls:
    image: yourls:latest
    restart: always
    volumes:
      - ./plugins:/var/www/html/user/plugins
      - ./wwwyouls:/var/www/
    environment:
      YOURLS_DB_PASS: "\${MYSQL_ROOT_PASSWORD}"
      YOURLS_SITE: "\${YOURLS_SITE}"
      YOURLS_USER: "\${YOURLS_USER}"
      YOURLS_PASS: "\${YOURLS_PASS}"
    depends_on:
      - mysql

  mysql:
    image: mysql:5.7
    restart: always
    volumes:
      - ./mysqllogs:/var/log/mysql
    environment:
      MYSQL_ROOT_PASSWORD: "\${MYSQL_ROOT_PASSWORD}"
      MYSQL_DATABASE: "\${MYSQL_DATABASE}"

  nginx:
    image: nginx:latest
    restart: always
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./nginxlogs:/var/log/nginx
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - ./certbot-data:/var/www/certbot
    ports:
      - 80:80
      - 443:443
    depends_on:
      - yourls

  certbot:
    image: certbot/certbot
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt
      - /var/lib/letsencrypt:/var/lib/letsencrypt
      - ./certbot-data:/var/www/certbot
      - ./certbot.sh:/certbot.sh
    entrypoint: "/bin/sh -c '/certbot.sh && sleep 2w'"
    depends_on:
      - nginx
EOF
check_status

# Создание начальной конфигурации Nginx
echo -e "${YELLOW}Создание начальной конфигурации Nginx...${NC}"
cat > nginx.conf <<EOF
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log error;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    keepalive_timeout  65;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  $DOMAIN;

        location ~ /.well-known/acme-challenge/ {
            root /var/www/certbot;
            allow all;
        }

        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    server {
        listen 443 ssl;
        server_name $DOMAIN;

        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

        location / {
            proxy_pass http://yourls;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF
check_status

# Создание скрипта для Certbot
echo -e "${YELLOW}Создание скрипта для Certbot...${NC}"
cat > certbot.sh <<EOF
#!/bin/sh

if [ ! -e "/etc/letsencrypt/live/$DOMAIN" ]; then
  certbot certonly --webroot --webroot-path /var/www/certbot --email $LETSENCRYPT_EMAIL --agree-tos --no-eff-email -d $DOMAIN --keep-until-expiring --non-interactive
fi

certbot renew --quiet --no-self-upgrade
EOF
chmod +x certbot.sh
check_status

# Создание директории для Certbot
echo -e "${YELLOW}Создание директории для Certbot...${NC}"
mkdir -p ./certbot-data
check_status

# Запуск контейнеров
echo -e "${YELLOW}Запуск контейнеров...${NC}"
docker-compose up -d
check_status

# Проверка корректности работы
echo -e "${YELLOW}Проверка корректности работы...${NC}"
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  echo -e "${GREEN}Сертификаты SSL успешно получены.${NC}"
else
  echo -e "${RED}Ошибка при получении сертификатов SSL.${NC}"
fi

if [ -d "./certbot-data" ]; then
  echo -e "${GREEN}Директория Certbot создана.${NC}"
else
  echo -e "${RED}Ошибка при создании директории Certbot.${NC}"
fi

echo -e "${GREEN}Установка завершена. Проверьте настройки вашего DNS и убедитесь, что домен указывает на IP-адрес вашего сервера.${NC}"


echo -e "${GREEN}Внимание! Страница доступна по адресу https://${DOMAIN}/admin${NC}"
