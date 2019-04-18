# PHP version we are targetting
ARG PHP_VERSION=7.2

# Set up php dependancies
FROM composer:1.8 as vendor

ENV APP_ENV=local
ENV APP_DEBUG=true

RUN mkdir -p database/seeds
RUN mkdir -p database/factories

COPY composer.json composer.json
COPY composer.lock composer.lock

RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --ignore-platform-reqs \
    --prefer-dist

# Build JS/css assets
FROM node:latest as frontend

RUN node --version
RUN mkdir -p /app/public

COPY package.json webpack.mix.js package-lock.json /app/
RUN mkdir /app/resources
COPY resources/ /app/resources/

WORKDIR /app

RUN yarn install
RUN yarn dev

# And build the app
FROM uogsoe/soe-php-apache:${PHP_VERSION}

ENV APP_ENV=local
ENV APP_DEBUG=true

COPY docker/start.sh /usr/local/bin/start
COPY docker/app-healthcheck /usr/local/bin/app-healthcheck
COPY docker/ldap.conf /etc/ldap/ldap.conf
COPY docker/custom_php.ini /usr/local/etc/php/conf.d/custom_php.ini
RUN chmod u+x /usr/local/bin/start /usr/local/bin/app-healthcheck

COPY --chown=www-data:www-data . /var/www/html
RUN ln -sf /run/secrets/.env /var/www/html/.env
COPY --from=vendor --chown=www-data:www-data /app/vendor/ /var/www/html/vendor/
COPY --from=frontend --chown=www-data:www-data /app/public/js/ /var/www/html/public/js/
COPY --from=frontend --chown=www-data:www-data /app/public/css/ /var/www/html/public/css/
COPY --from=frontend --chown=www-data:www-data /app/mix-manifest.json /var/www/html/mix-manifest.json

RUN rm -fr /var/www/html/bootstrap/cache/*.php
RUN php /var/www/html/artisan storage:link
RUN php /var/www/html/artisan view:cache
RUN php /var/www/html/artisan route:cache

CMD ["/usr/local/bin/start"]
