#!/bin/sh
set -eu
mkdir -p /var/www/html/runtime/log /var/www/html/runtime/session /var/www/html/runtime/temp /var/www/html/storage/install /data
chown -R www-data:www-data /var/www/html/runtime /var/www/html/storage/install /data
exec "$@"
