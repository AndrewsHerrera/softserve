#!/bin/bash
apt update -y
apt install -y nginx
systemctl enable nginx

openssl req  -nodes -new -x509  -keyout ./server.key -out ./server.cert -subj "/C=US/ST=State/L=City/O=company/OU=Com/CN=andrewsherrera.com"
openssl req  -nodes -new -x509  -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/C=US/ST=State/L=City/O=company/OU=Com/CN=andrewsherrera.com"

mkdir -p /etc/nginx/snippets/
touch /etc/nginx/snippets/self-signed.conf

cat > /etc/nginx/snippets/self-signed.conf << EOL
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
EOL

touch /etc/nginx/snippets/ssl-params.conf
cat > /etc/nginx/snippets/ssl-params.conf << EOL 
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
ssl_ecdh_curve secp384r1;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
EOL

cat > /etc/nginx/sites-available/default << EOL
server {
        root /var/www/html;
        server_name _;
        listen 80 default_server;
        listen [::]:80 default_server;
        return 301 https://$server_name$request_uri;
}
server {
        listen 443 ssl http2 default_server;
        listen [::]:443 ssl http2 default_server;
        include snippets/self-signed.conf;
        include snippets/ssl-params.conf;
}
EOL

systemctl restart nginx