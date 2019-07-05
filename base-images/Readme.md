# Dockerfile for PHP7 and Apache

This is just a base Dockerfile used as the base for our CI and production images.  It gives you Apache, PHP 7.x and a few commonly used libraries that PHP/Laravel apps use.

## To use from the docker hub 

Eg:

```
// for php7.2 + composer
docker pull uogsoe/soe-php-apache:7.2
// for php7.2 + composer + pcov
docker pull uogsoe/soe-php-apache:7.2-ci
```

## Building the images

Just run the `build.sh` script.  It needs to have the [buildx](https://github.com/docker/buildx) docker feature enabled if you don't already have it.

The script will by default build images for each PHP version in the `VERSIONS` array defined in the script.  It uses buildx to do multiple architectures for each PHP version : 

- linux/amd64
- linux/arm/v7

