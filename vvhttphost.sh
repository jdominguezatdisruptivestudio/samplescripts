#!/bin/bash

# Exit on error
set -e

# Create vriables
mydomain=$1
myip=$2
myport=$3

block="/etc/nginx/conf.d/$mydomain.conf"

echo ""
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "This script will do as follows:"
echo ""
echo "Verify dns record                         Create vhost"
echo "Get lets encrypt cert                             Update vhos with TLS"
echo "Test configuration                                Restart nginx"
echo ""
echo "letsencrypt http1 challenge will only work if there is only one proxy active!"
echo ""
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Verifying DNS, Domain should be pointing to 144.126.241.239"
echo ""
domains=($mydomain www.$mydomain)
for domain in "${domains[@]}"; do
    echo "$domain : $(dig +short a $domain | tail -n1)"
done
echo ""
read -p "Press enter to continue or ctrl+c to abort"

echo ""
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Creating the Nginx virtualhost file"

sudo tee $block > /dev/null <<EOF
upstream $mydomain-upstream{
    server $myip:$myport;
}

server {
        server_name $mydomain www.$mydomain;
        listen 80   proxy_protocol;
        set_real_ip_from 10.130.148.210;
        real_ip_header proxy_protocol;

        location ^~ /.well-known/acme-challenge/ {
            default_type "text/plain";
            allow all;
            root /var/www/letsencrypt;
            autoindex    on;
        }

        location / {
                return 301 https://\$host\$request_uri;
        }

}

EOF

echo ""
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Getting the domain certificates"
echo ""
certbot certonly --webroot -w /var/www/letsencrypt -d $mydomain -d www.$mydomain

echo ""
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Confirming before updating virtual host with TLS"
echo ""
read -p "Press enter to continue or ctrl+c to abort"

echo ""
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Finishing virtual host updates"
echo ""

cat << EOF >> $block
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

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Test configuration and restart nginx if successful"
nginx -t

read -p "Press enter to continue or ctrl+c to abort"

systemctl reload nginx.service
echo ""

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Updting hostfiles and certificates in webproxy2"
echo ""
read -p "Press enter to continue or ctrl+c to abort"
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
