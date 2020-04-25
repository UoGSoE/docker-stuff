### PHP version we are targetting
ARG PHP_VERSION=7.4

FROM uogsoe/soe-php-apache:${PHP_VERSION} as prod

WORKDIR /var/www/html

USER nobody

ENV APP_ENV=testing
ENV APP_DEBUG=1

RUN php artisan migrate

CMD ["./vendor/bin/phpunit", "--testdox", "--stop-on-defect"]

