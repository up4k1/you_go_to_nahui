#!/bin/bash

# Проверка и установка Docker и Docker Compose
if ! [ -x "$(command -v docker)" ]; then
  echo 'Установка Docker...'
  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt update
  sudo apt install -y docker-ce
  echo 'Docker установлен.'
else
  echo 'Docker уже установлен.'
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Установка Docker Compose...'
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo 'Docker Compose установлен.'
else
  echo 'Docker Compose уже установлен.'
fi

# Запрос основной информации от пользователя
read -p "Введите имя домена (например, short.ru): " DOMAIN
read -p "Введите имя пользователя для YOURLS: " YOURLS_USER
read -p "Введите пароль для YOURLS: " YOURLS_PASS
read -p "Введите email для Let's Encrypt: " LETSENCRYPT_EMAIL
read -p "Введите пароль для MySQL: " MYSQL_ROOT_PASSWORD

# Создание директории для YOURLS
mkdir -p yourls

# Создание .env файла для YOURLS
cat > yourls/.env <<EOF
YOURLS_SITE=https://$DOMAIN
YOURLS_USER=$YOURLS_USER
YOURLS_PASS=$YOURLS_PASS
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=yourls
EOF

# Создание Docker Compose файла (docker-compose.yml)
cat > yourls/docker-compose.yml <<EOF
version: '3'

services:
  yourls:
    image: yourls:latest
    restart: always
    ports:
      - 8080:80
    env_file:
      - .env
    depends_on:
      - mysql

  mysql:
    image: mysql:5.7
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}

  nginx:
    image: nginx:latest
    restart: always
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - /etc/letsencrypt:/etc/letsencrypt:ro
    ports:
      - 80:80
      - 443:443
    depends_on:
      - yourls
EOF

# Создание начальной конфигурации Nginx
cat > yourls/nginx.conf <<EOF
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
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

    server {
        listen       80;
        server_name  $DOMAIN;

        location ~ /.well-known/acme-challenge/ {
            root /var/www/certbot;
            allow all;
        }

        location / {
            proxy_pass http://yourls;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
}
EOF

# Создание скрипта для Certbot
cat > yourls/certbot.sh <<EOF
#!/bin/sh

if [ ! -e "/etc/letsencrypt/live/$DOMAIN" ]; then
  certbot certonly --webroot --webroot-path /var/www/certbot --email $LETSENCRYPT_EMAIL --agree-tos --no-eff-email -d $DOMAIN --keep-until-expiring --non-interactive
fi

certbot renew
EOF

chmod +x yourls/certbot.sh

# Создание директории для Certbot
mkdir -p yourls/certbot-data

# Запуск контейнеров
cd yourls
docker-compose up -d

echo "Установка завершена. Проверьте настройки вашего DNS и убедитесь, что домен указывает на IP-адрес вашего сервера."
