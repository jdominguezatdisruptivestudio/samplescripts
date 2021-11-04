#!/bin/bash

# Exit on error
set -e

# Create vriables
mydomain=$1
myip=$2
myport=$3

dns=$4

root="/var/www/$mydomain"
block="/etc/nginx/conf.d/$mydomain.conf"

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Use DNS challenge to get the certificate"

certbot certonly --text --agree-tos --email juan@disruptivestudio.com --no-eff-email --dns-$dns --dns-$dns-credentials /root/.secrets/certbot/$dns.ini --dns-$dns-propagation-seconds 60 -d $mydomain -d www.$mydomain
echo ""

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Creating the Nginx virtualhost file"
#
sudo tee $block > /dev/null <<EOF
upstream $mydomain-upstream{
    server $myip:$myport;
}

server {
        server_name $mydomain www.$mydomain;
        listen 80   proxy_protocol;
        set_real_ip_from 10.130.148.210;
        real_ip_header proxy_protocol;

        # redirects external request https with the right url
        return 301 https://\$host\$request_uri;

        }


server {
        server_name $mydomain www.$mydomain;
        listen 443   proxy_protocol;
        set_real_ip_from 10.130.148.210;
        real_ip_header proxy_protocol;

        include /etc/nginx/snippets/ssl.conf;

        ssl_certificate_key /etc/letsencrypt/live/$mydomain/privkey.pem;
        ssl_certificate /etc/letsencrypt/live/$mydomain/fullchain.pem;
        ssl_trusted_certificate /etc/letsencrypt/live/$mydomain/fullchain.pem;

        location / {
                proxy_pass http://$mydomain-upstream;
                proxy_set_header Host             \$host;
                proxy_set_header X-Real-IP        \$remote_addr;
                proxy_set_header  X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header  X-Forwarded-Proto \$scheme;
                proxy_set_header  X-Forwarded-Ssl on; # Optional
                proxy_set_header  X-Forwarded-Port \$server_port;
                proxy_set_header  X-Forwarded-Host \$host;

                # WebSocket support
                proxy_http_version 1.1;
                proxy_set_header Upgrade \$http_upgrade;
                proxy_set_header Connection "upgrade";
        }
}

EOF
echo ""

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Test configuration and reload nginx if successful"
nginx -t
systemctl restart nginx.service
echo ""

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Updting hostfiles and certificates in webproxy2"
echo ""
rsync -a --no-o --no-g /etc/nginx/conf.d root@webproxy2:/etc/nginx
rsync -a --no-o --no-g /etc/letsencrypt root@webproxy2:/etc
echo ""

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Waiting 4 seconds to restart webproxy2"
sleep 4s
systemctl --host root@webproxy2 restart nginx
echo ""

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "All done"
echo ""
echo ""
