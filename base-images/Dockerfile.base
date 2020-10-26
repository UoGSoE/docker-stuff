ARG PHP_VERSION

FROM php:${PHP_VERSION}-apache as prod

ARG PHP_VERSION
ARG PHP_REDIS_VERSION=5.0.2
ARG COMPOSER_VERSION=2.0.1

LABEL org.opencontainers.image.source=https://github.com/UoGSoE/docker-stuff/ \
      org.opencontainers.image.vendor="University of Glasgow, School of Engineering" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="PHP ${PHP_VERSION} + Apache" \
      org.opencontainers.image.description="PHP ${PHP_VERSION} with Apache and a set of php/os packages suitable for running Laravel apps"

# our default timezone and langauge
ENV TZ=Europe/London
ENV LANG=en_GB.UTF-8

# Note: we only install reliable/core 1st-party php extensions here.
#       If your app needs custom ones install them in the apps own
#       Dockerfile _and pin the versions_! Eg:
#       RUN pecl install memcached-2.2.0

RUN apt-get update \
    # install some OS packages we need
    && apt-get install -y --no-install-recommends libfreetype6-dev libjpeg62-turbo-dev libpng-dev libgmp-dev libldap2-dev netcat curl sqlite3 libsqlite3-dev libzip-dev unzip vim-tiny gosu git \
    # install php extensions
    && case "${PHP_VERSION}" in "7.4"|"rc") docker-php-ext-configure gd --with-freetype --with-jpeg ;; *) docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ ;; esac \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql pdo_sqlite zip gmp bcmath pcntl ldap sysvmsg exif \
    # install the redis php extension
    && pecl install redis-${PHP_REDIS_VERSION} \
    && echo "extension=redis.so" > /usr/local/etc/php/conf.d/redis.ini \
    # clear the apt cache
    && rm -rf /var/lib/apt/lists/* /var/cache/debconf/templates* /var/lib/dpkg/status/* /var/log/dpkg.log /var/log/apt/term.log /var/cache/debconf/config.dat \
    # enable apache mod_rewrite for 'pretty' urls and mod_headers so we can add the container id
    && a2enmod rewrite \
    && a2enmod headers \
    # give apache access to the system hostname (ie, the container-id)
    && echo 'export HOSTNAME=`uname -n`' >> /etc/apache2/envvars \
    # install composer
    && curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php --version=${COMPOSER_VERSION} --no-ansi --install-dir=/usr/local/bin --filename=composer --snapshot \
    && rm -f /tmp/composer-setup.* \
    # set the system timezone
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

# copy in the generic vhost for our 'default' app setup
COPY vhost.conf /etc/apache2/sites-available/000-default.conf
# add in the basic php ini settings for uploading files and our timezone
COPY uploads.ini timezone.ini /usr/local/etc/php/conf.d/
# and expose apache to docker
EXPOSE 80

FROM prod as ci

ARG PCOV_VERSION=1.0.6

# The only additions for CI/QA is the 'pcov' extension by PHP internals developer
# Joe Watkins (it provides code-coverage statistics without slowing down code.
# https://github.com/krakjoe/pcov)
ENV DRIVER pcov
# pecl install currently commented out as no pre-built package for ARM
#RUN pecl install pcov \
#    && docker-php-ext-enable pcov \
#    && echo "pcov.enabled = 1" > /usr/local/etc/php/conf.d/pcov.ini
WORKDIR /tmp
RUN apt-get update \
    && curl -sLo pcov.tar.gz https://github.com/krakjoe/pcov/archive/v${PCOV_VERSION}.tar.gz \
    && tar -xvzf pcov.tar.gz \
    && cd pcov-${PCOV_VERSION} \
    && phpize \
    && ./configure --enable-pcov \
    && make \
    && make install \
    && cd .. \
    && rm -fr pcov*
