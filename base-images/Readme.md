# Dockerfile for PHP7 and Apache

This is just a base Dockerfile used as the base for our CI and production images.  It gives you Apache, PHP 7.x and a few commonly used libraries that PHP/Laravel apps use.

## To use from the docker hub 

Eg:

```
// for php7.2
docker pull uogsoe/soe-php-apache:7.2
// for php7.2 + pcov + composer + prestissimo
docker pull uogsoe/soe-php-apache:7.2-ci
```

