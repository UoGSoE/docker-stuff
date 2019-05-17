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

#- Copy our start scripts and php/ldap configs in
COPY docker/start.sh /usr/local/bin/start
COPY docker/app-healthcheck /usr/local/bin/app-healthcheck
COPY docker/ldap.conf /etc/ldap/ldap.conf
COPY docker/custom_php.ini /usr/local/etc/php/conf.d/custom_php.ini
RUN chmod u+x /usr/local/bin/start /usr/local/bin/app-healthcheck

#- Copy in our code
COPY --chown=www-data:www-data . /var/www/html

#- Symlink the docker secret to the local .env so Laravel can see it
RUN ln -sf /run/secrets/.env /var/www/html/.env

#- Copy in our front-end assets
COPY --from=frontend --chown=www-data:www-data /app/public/js/ /var/www/html/public/js/
COPY --from=frontend --chown=www-data:www-data /app/public/css/ /var/www/html/public/css/
COPY --from=frontend --chown=www-data:www-data /app/mix-manifest.json /var/www/html/mix-manifest.json

#- Install all our php non-dev dependencies
RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --no-dev \
    --prefer-dist

#- Clean up and cache our apps settings/views/routing
RUN rm -fr /var/www/html/bootstrap/cache/*.php && \
    php /var/www/html/artisan storage:link && \
    php /var/www/html/artisan view:cache && \
    php /var/www/html/artisan route:cache

CMD ["/usr/local/bin/start"]

# And build the ci version of the app
FROM prod as ci

ENV APP_ENV=local
ENV APP_DEBUG=1

#- Install our php dependencies including the dev ones
RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist
