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

read -p "Введите имя домена (например, example.com): " DOMAIN
read -p "Введите ваш email для Let's Encrypt: " EMAIL
read -p "Введите имя пользователя для YOURLS: " YOURLS_USER
read -p "Введите пароль для YOURLS: " YOURLS_PASS
read -p "Введите пароль для MySQL: " MYSQL_ROOT_PASSWORD

# Создание директории для plugins, если она еще не существует
mkdir -p yourls-plugins

# Запись переменных в .env файл
cat << EOF > .env
DOMAIN=$DOMAIN
EMAIL=$EMAIL
YOURLS_SITE=https://$DOMAIN
YOURLS_USER=$YOURLS_USER
YOURLS_PASS=$YOURLS_PASS
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=yourls
EOF

# Создание файла docker-compose.yml
cat << EOF > docker-compose.yml
version: '3'

services:
  traefik:
    image: traefik:v2.5
    container_name: traefik
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "./letsencrypt:/letsencrypt"
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=\${EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"

  yourls:
    image: yourls
    container_name: yourls
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.yourls.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.yourls.entrypoints=websecure"
      - "traefik.http.routers.yourls.tls.certresolver=myresolver"
    environment:
      YOURLS_DB_HOST: mysql
      YOURLS_DB_USER: root
      YOURLS_DB_PASS: \${MYSQL_ROOT_PASSWORD}
      YOURLS_DB_NAME: \${MYSQL_DATABASE}
      YOURLS_SITE: \${YOURLS_SITE}
    volumes:
      - ./yourls-plugins:/var/www/html/user/plugins
    depends_on:
      - mysql

  mysql:
    image: mysql:5.7
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}
    volumes:
      - ./mysql-data:/var/lib/mysql
EOF

echo "Запуск контейнеров..."
docker-compose up -d

echo "Контейнеры успешно запущены."
