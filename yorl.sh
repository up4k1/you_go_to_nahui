#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Spinner for loading animation
spin() {
    spinner="/|\\-/|\\-"
    while :
    do 
        for i in ${spinner[@]}; do
            echo -ne "\r$i"
            sleep 0.2
        done
    done
}

# Check and install Docker
echo -e "${BLUE}Проверка на наличие Docker...${NC}"
if ! [ -x "$(command -v docker)" ]; then
    spin &
    SPIN_PID=$!
    disown
    
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce

    kill -9 $SPIN_PID
    wait $SPIN_PID 2>/dev/null
    echo -e "${GREEN}Docker установлен.${NC}"
else
    echo -e "${GREEN}Docker уже установлен.${NC}"
fi

# Check and install Docker Compose
echo -e "${BLUE}Проверка и установка Docker Compose...${NC}"
if ! [ -x "$(command -v docker-compose)" ]; then
    spin &
    SPIN_PID=$!

    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    kill -9 $SPIN_PID
    wait $SPIN_PID 2>/dev/null
    echo -e "${GREEN}Docker Compose установлен.${NC}"
else
    echo -e "${GREEN}Docker Compose уже установлен.${NC}"
fi

# Prompt user for input
read -p "Введите домен без https и www (e.g., example.com): " DOMAIN
read -p "Введите email для Let's Encrypt: " EMAIL
read -p "Введите имя пользователя для админ-панели YOURLS: " YOURLS_USER
read -p "Введите пароль для админ-панели YOURLS: " YOURLS_PASS
read -p "Введите MySQL root пароль: " MYSQL_ROOT_PASSWORD

# Create directory for plugins if it doesn't exist
mkdir -p yourls-plugins

# Write environment variables to .env file
cat << EOF > .env
DOMAIN=$DOMAIN
EMAIL=$EMAIL
YOURLS_SITE=https://$DOMAIN
YOURLS_USER=$YOURLS_USER
YOURLS_PASS=$YOURLS_PASS
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=yourls
EOF

# Create docker-compose.yml file
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
      YOURLS_USER: \${YOURLS_USER}
      YOURLS_PASS: \${YOURLS_PASS}
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

echo -e "${YELLOW}Запуск контейнеров...${NC}"
spin &
SPIN_PID=$!

docker-compose up -d

kill -9 $SPIN_PID
wait $SPIN_PID 2>/dev/null
echo -e "${GREEN}Контейнеры запущены.${NC}"
