# PHP version we are targetting
ARG PHP_VERSION=7.2

# Build JS/css assets
FROM node:10 as frontend

WORKDIR /app

RUN mkdir -p /app/public /app/resources

COPY --chown=node:node package.json webpack.mix.js package-lock.json /app/
COPY --chown=node:node resources/ /app/resources/

RUN npm install && \
    npm run production && \
    npm cache clean --force

# And build the prod app
FROM uogsoe/soe-php-apache:${PHP_VERSION} as prod

WORKDIR /var/www/html

ENV APP_ENV=production
ENV APP_DEBUG=0

COPY docker/start.sh /usr/local/bin/start
COPY docker/app-healthcheck /usr/local/bin/app-healthcheck
COPY docker/ldap.conf /etc/ldap/ldap.conf
COPY docker/custom_php.ini /usr/local/etc/php/conf.d/custom_php.ini
RUN chmod u+x /usr/local/bin/start /usr/local/bin/app-healthcheck

COPY --chown=www-data:www-data . /var/www/html
RUN ln -sf /run/secrets/.env /var/www/html/.env
COPY --from=frontend --chown=www-data:www-data /app/public/js/ /var/www/html/public/js/
COPY --from=frontend --chown=www-data:www-data /app/public/css/ /var/www/html/public/css/
COPY --from=frontend --chown=www-data:www-data /app/mix-manifest.json /var/www/html/mix-manifest.json

RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --no-dev \
    --prefer-dist

RUN rm -fr /var/www/html/bootstrap/cache/*.php && \
    php /var/www/html/artisan storage:link && \
    php /var/www/html/artisan view:cache && \
    php /var/www/html/artisan route:cache

CMD ["/usr/local/bin/start"]

# And build the ci version of the app
FROM prod as ci

ENV APP_ENV=local
ENV APP_DEBUG=1

RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist
