#!/bin/bash

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
