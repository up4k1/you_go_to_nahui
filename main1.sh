#!/bin/bash

# Проверка наличия Docker
if ! command -v docker &> /dev/null
then
    echo "Установка Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Проверка наличия Docker Compose
if ! command -v docker-compose &> /dev/null
then
    echo "Установка Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Скачивание и выполнение скрипта
sudo curl -k https://raw.githubusercontent.com/up4k1/you_go_to_nahui/main/main.sh -o main.sh
sudo bash main.sh
