#!/bin/bash

# Запрос списка доменов
read -p "Введите домены, разделенные пробелом (например, example.com secondexample.com): " DOMAINS
read -p "Введите Email для Let's Encrypt: " EMAIL

# Пути к файлам конфигурации
NGINX_SSL_CONF="nginx-ssl.conf"
NGINX_CONF="nginx.conf"

# Обновление nginx.conf для добавления новых доменов
echo "Обновляю nginx.conf..."
for DOMAIN in $DOMAINS; do
    if ! grep -q "$DOMAIN" "$NGINX_CONF"; then
        sed -i "/server_name / s/$/ $DOMAIN;/" "$NGINX_CONF"
    fi
done
echo "nginx.conf обновлен."

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

# Выпуск SSL-сертификатов для новых доменов
for DOMAIN in $DOMAINS; do
    docker-compose exec nginx certbot certonly --webroot -w /var/www/certbot -d $DOMAIN --email $EMAIL --agree-tos --no-eff-email --keep-until-expiring --quiet
    if [ $? -eq 0 ]; then
        echo "SSL-сертификат для $DOMAIN успешно выписан."
    else
        echo "Ошибка при выпуске SSL-сертификата для $DOMAIN."
    fi
done

# Копирование обновленной конфигурации SSL в контейнер
echo "Обновляю конфигурацию SSL в контейнере Nginx..."
cat "$NGINX_SSL_CONF" | docker exec -i $NGINX_CONTAINER_ID sh -c 'cat > /etc/nginx/conf.d/default.conf'

# Перезапуск Nginx
docker-compose restart nginx
echo "Nginx перезапущен."
