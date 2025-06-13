### PHP version we are targetting
ARG PHP_VERSION=8.4


### Placeholder for basic dev stage for use with docker-compose
FROM uogsoe/soe-php-apache:${PHP_VERSION} as dev

COPY docker/app-start docker/app-healthcheck /usr/local/bin/
RUN chmod u+x /usr/local/bin/app-start /usr/local/bin/app-healthcheck
CMD ["tini", "--", "/usr/local/bin/app-start"]



### Prod php dependencies
FROM dev as prod-composer
ARG FLUX_USERNAME
ARG FLUX_LICENSE_KEY
ENV APP_ENV=production
ENV APP_DEBUG=0

WORKDIR /var/www/html

USER nobody

#- make paths that the laravel composer.json expects to exist
RUN mkdir -p database
#- copy the seeds and factories so that composer generates autoload entries for them
COPY database/seeders database/seeders
COPY database/factories database/factories


COPY --chown=nobody composer.* ./
RUN echo ${FLUX_USERNAME}
RUN echo ${FLUX_LICENSE_KEY}

RUN composer config http-basic.composer.fluxui.dev "${FLUX_USERNAME}" "${FLUX_LICENSE_KEY}"

RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --no-dev \
    --prefer-dist

### QA php dependencies
FROM prod-composer as qa-composer
ARG FLUX_USERNAME
ARG FLUX_LICENSE_KEY
ENV APP_ENV=local
ENV APP_DEBUG=1

RUN composer config http-basic.composer.fluxui.dev "${FLUX_USERNAME}" "${FLUX_LICENSE_KEY}"

RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist

### Build JS/css assets
FROM node:20.13.1 as frontend

# workaround for mix.version() webpack bug
RUN ln -s /home/node/public /public

USER node
WORKDIR /home/node

RUN mkdir -p /home/node/public/css /home/node/public/js /home/node/resources

COPY --chown=node:node package*.json *.js .babelrc* /home/node/
COPY --chown=node:node resources/js* /home/node/resources/js
COPY --chown=node:node resources/sass* /home/node/resources/sass
COPY --chown=node:node resources/scss* /home/node/resources/scss
COPY --chown=node:node resources/css* /home/node/resources/css
COPY --chown=node:node resources/views* /home/node/resources/views
COPY --chown=node:node --from=qa-composer /var/www/html/vendor /home/node/vendor

RUN npm install && \
    npm run build && \
    npm cache clean --force


### And build the prod app
FROM dev as prod

WORKDIR /var/www/html

ENV APP_ENV=production
ENV APP_DEBUG=0

#- Copy our start scripts and php/ldap configs in
COPY docker/ldap.conf /etc/ldap/ldap.conf
COPY docker/custom_php.ini /usr/local/etc/php/conf.d/custom_php.ini

#- Copy in our prod php dep's
COPY --from=prod-composer /var/www/html/vendor /var/www/html/vendor

#- Copy in our front-end assets
RUN mkdir -p /var/www/html/public/build
COPY --from=frontend /home/node/public/build /var/www/html/public/build

#- Copy in our code
COPY . /var/www/html

#- Clear any cached composer stuff
RUN rm -fr /var/www/html/bootstrap/cache/*.php

#- If horizon is installed force it to rebuild it's public assets
RUN if grep -q horizon composer.json; then php /var/www/html/artisan horizon:publish ; fi

#- Symlink the docker secret to the local .env so Laravel can see it
RUN ln -sf /run/secrets/.env /var/www/html/.env

#- Clean up and production-cache our apps settings/views/routing
RUN php /var/www/html/artisan storage:link && \
    php /var/www/html/artisan view:cache && \
    php /var/www/html/artisan route:cache && \
    chown -R www-data:www-data storage bootstrap/cache

#- Set up the default healthcheck
HEALTHCHECK --start-period=30s CMD /usr/local/bin/app-healthcheck



### Build the ci version of the app (prod+dev packages)
FROM prod as ci

ENV APP_ENV=local
ENV APP_DEBUG=0

#- Copy in our QA php dep's
COPY --from=qa-composer /var/www/html/vendor /var/www/html/vendor

#- Clear the caches
ENV CACHE_STORE=array
RUN php /var/www/html/artisan optimize:clear
