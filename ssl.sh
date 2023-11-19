#!/bin/bash

# Запрос списка доменов
read -p "Введите домены, разделенные пробелом (например, example.com secondexample.com): " DOMAINS
read -p "Введите Email для Let's Encrypt: " EMAIL

# Пути к файлам конфигурации
NGINX_SSL_CONF="nginx-ssl.conf"
NGINX_CONF="nginx.conf"

# Обновление nginx.conf для добавления новых доменов
echo "Обновляю nginx.conf..."
sed -i "/server_name /c\    server_name $DOMAINS;" "$NGINX_CONF"
echo "nginx.conf обновлен."

# Выпуск SSL-сертификатов для новых доменов
for DOMAIN in $DOMAINS; do
    docker-compose exec nginx certbot certonly --webroot -w /var/www/certbot -d $DOMAIN --email $EMAIL --agree-tos --no-eff-email --keep-until-expiring --quiet
    if [ $? -eq 0 ]; then
        echo "SSL-сертификат для $DOMAIN успешно выписан."
    else
        echo "Ошибка при выпуске SSL-сертификата для $DOMAIN."
    fi
done

# Добавление конфигурации SSL для каждого домена
echo "Добавляю конфигурации SSL в $NGINX_SSL_CONF..."
for DOMAIN in $DOMAINS; do
    if ! grep -q "server_name $DOMAIN;" "$NGINX_SSL_CONF"; then
        cat <<EOF >>"$NGINX_SSL_CONF"
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
        echo "Конфигурация для $DOMAIN добавлена."
    fi
done

# Получение ID контейнера Nginx
NGINX_CONTAINER_ID=$(docker-compose ps -q nginx)

# Копирование обновленной конфигурации в контейнер и перезапуск Nginx
echo "Обновляю конфигурацию в контейнере Nginx..."
docker cp "$NGINX_SSL_CONF" "$NGINX_CONTAINER_ID:/etc/nginx/conf.d/default.conf"
docker cp "$NGINX_CONF" "$NGINX_CONTAINER_ID:/etc/nginx/nginx.conf"
docker-compose restart nginx
echo "Nginx перезапущен."
