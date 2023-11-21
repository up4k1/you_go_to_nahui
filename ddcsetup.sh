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
    sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi
