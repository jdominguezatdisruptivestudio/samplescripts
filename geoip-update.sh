#!/bin/bash

MON=11
YR=2021

wget https://download.db-ip.com/free/dbip-country-lite--.csv.gz -O /usr/share/xt_geoip/dbip-country-lite.csv.gz
gunzip /usr/share/xt_geoip/dbip-country-lite.csv.gz
chmod +x /lib/xtables-addons/xt_geoip_build
/lib/xtables-addons/xt_geoip_dl && /lib/xtables-addons/xt_geoip_build -D "/usr/share/xt_geoip" -S
#rm /usr/share/xt_geoip/dbip-country-lite.csv
