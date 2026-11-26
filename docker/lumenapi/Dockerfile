FROM redis:8.0-bookworm AS redis-runtime
FROM node:22-bookworm-slim AS node-runtime

FROM php:8.4-fpm-bookworm
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates chromium curl nginx supervisor xz-utils \
      libcurl4-openssl-dev libfreetype6-dev libicu-dev libjpeg62-turbo-dev \
      libonig-dev libpng-dev libsqlite3-dev libxml2-dev libzip-dev unzip \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j2 bcmath curl gd intl mbstring mysqli opcache pcntl pdo_mysql pdo_sqlite sockets zip \
 && pecl install redis \
 && docker-php-ext-enable redis \
 && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default
COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node-runtime /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && /usr/local/bin/node --version \
 && /usr/local/bin/npm --version
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY --from=redis-runtime /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=redis-runtime /usr/local/bin/redis-cli /usr/local/bin/redis-cli
WORKDIR /var/www/html
COPY . /var/www/html
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader \
 && mkdir -p runtime/log runtime/session runtime/temp storage/install /data /opt/lumen-renderer \
 && rm -f storage/install/install.lock \
 && chown -R www-data:www-data scripts runtime storage /data
COPY renderer/server.js renderer/package.json renderer/package-lock.json /opt/lumen-renderer/
RUN cd /opt/lumen-renderer && npm ci --omit=dev && npm cache clean --force
COPY docker/lumenapi/php.ini /usr/local/etc/php/conf.d/99-lumenapi.ini
COPY docker/lumenapi/zz-lumenapi.conf /usr/local/etc/php-fpm.d/zz-lumenapi.conf
COPY docker/lumenapi/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/lumenapi/supervisord.conf /etc/supervisor/conf.d/lumenapi.conf
COPY docker/lumenapi/entrypoint.sh /usr/local/bin/lumenapi-entrypoint
RUN chmod 0755 /usr/local/bin/lumenapi-entrypoint
ENV CHROMIUM_PATH=/usr/bin/chromium RENDERER_HOST=127.0.0.1 RENDERER_PORT=3000
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/lumenapi-entrypoint"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
