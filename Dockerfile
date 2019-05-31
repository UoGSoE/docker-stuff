# PHP version we are targetting
ARG PHP_VERSION=7.2

# Build JS/css assets
FROM node:10 as frontend

WORKDIR /app

RUN mkdir -p /app/public /app/resources

COPY --chown=node:node package*.json webpack.mix.js /app/
COPY --chown=node:node resources/ /app/resources/

RUN npm install && \
    npm run production && \
    npm cache clean --force

# Install the prod php packages
FROM uogsoe/soe-php-apache:${PHP_VERSION} as prod-composer

USER www-data

WORKDIR /var/www/html

COPY composer.* /var/www/html/
COPY database/ /var/www/html/database/

RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --no-dev \
    --prefer-dist

# Install the qa/dev/test php packages
FROM uogsoe/soe-php-apache:${PHP_VERSION} as qa-composer

USER www-data

WORKDIR /var/www/html

COPY composer.* /var/www/html/
COPY database/ /var/www/html/database/

RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist


# And build the prod app
FROM uogsoe/soe-php-apache:${PHP_VERSION} as prod

WORKDIR /var/www/html

ENV APP_ENV=production
ENV APP_DEBUG=0

#- Copy our start scripts and php/ldap configs in
COPY docker/ldap.conf /etc/ldap/ldap.conf
COPY docker/custom_php.ini /usr/local/etc/php/conf.d/custom_php.ini
COPY docker/app-start docker/app-healthcheck /usr/local/bin/
RUN chmod u+x /usr/local/bin/app-start /usr/local/bin/app-healthcheck

#- Copy in our code
COPY . /var/www/html

#- Symlink the docker secret to the local .env so Laravel can see it
RUN ln -sf /run/secrets/.env /var/www/html/.env

#- Copy in our front-end assets
COPY --from=frontend /app/public/js /var/www/html/public/js
COPY --from=frontend /app/public/css /var/www/html/public/css
COPY --from=frontend /app/mix-manifest.json /var/www/html/mix-manifest.json
COPY --from=prod-composer /var/www/html/vendor /var/www/html/vendor

#- Install all our php non-dev dependencies
# RUN composer install \
#     --no-interaction \
#     --no-plugins \
#     --no-scripts \
#     --no-dev \
#     --prefer-dist

#- Clean up and cache our apps settings/views/routing
RUN rm -fr /var/www/html/bootstrap/cache/*.php && \
    chown -R www-data:www-data storage bootstrap/cache && \
    php /var/www/html/artisan storage:link && \
    php /var/www/html/artisan view:cache && \
    php /var/www/html/artisan route:cache

#- Set up the default healthcheck
HEALTHCHECK --start-period=30s CMD /usr/local/bin/app-healthcheck

#- And off we go...
CMD ["/usr/local/bin/app-start"]

# Build the ci version of the app
FROM prod as ci

ENV APP_ENV=local
ENV APP_DEBUG=1

#- Install our php dependencies including the dev ones
COPY --from=qa-composer /var/www/html/vendor /var/www/html/vendor

