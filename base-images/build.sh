#!/bin/bash

set -e

BASE_NAME="uogsoe/soe-php-apache"
VERSIONS=( "7.1" "7.2" "7.3" )

PNAME=`basename $0`
LOGFILE=`mktemp /tmp/${PNAME}.XXXXXX` || exit 1
echo "Logging to ${LOGFILE}"

for VERSION in "${VERSIONS[@]}";
do
    echo "Building ${VERSION}..."
    docker build --pull --no-cache --build-arg PHP_VERSION=${VERSION} -t "${BASE_NAME}":"${VERSION}" -f Dockerfile.base . >> "${LOGFILE}"
    echo "Pushing ${VERSION}..."

    echo "Building ${VERSION}-ci..."
    docker build --pull --build-arg PHP_VERSION=${VERSION} -t "${BASE_NAME}":"${VERSION}-ci" -f Dockerfile.base-ci . >> "${LOGFILE}"
    echo "Pushing ${VERSION}-ci..."
done

