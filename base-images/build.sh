#!/bin/bash

# Note: you need the 'buildx' feature of docker enabled to run this so we can 
# build images for x86, arm etc. eg :
# $ docker buildx create --name mybuilder
# $ docker buildx use mybuilder
# $ docker buildx build --build-arg PHP_VERSION=7.3 --platform linux/amd64,linux/arm64,linux/arm/v7 -t myimage:latest .
#

ABSOLUTE_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOCKER_FILE="${ABSOLUTE_PATH}/Dockerfile.base"
BASE_NAME="uogsoe/soe-php-apache"
# Note: these should be in ascending order - the ':latest' tag is taken from the last element
VERSIONS=( "7.1" "7.2" "7.3" "7.4" )
LATEST=${VERSIONS[@]: -1:1}
#CMD="docker buildx build --pull --push --no-cache --platform linux/amd64,linux/arm/v7" 
CMD="docker buildx build --pull --push --platform linux/amd64,linux/arm/v7" 
PNAME=`basename $0`
LOGFILE=`mktemp /tmp/${PNAME}.XXXXXX` || exit 1
export DOCKER_BUILDKIT=1

docker buildx &> /dev/null
if [ $? -ne 0 ]
then
  echo "Aborting."
  echo "You need to have docker buildx available. See https://github.com/docker/buildx"
  exit 1
fi

set -e

echo "Logging to ${LOGFILE}"

for VERSION in "${VERSIONS[@]}";
do
    echo "Building ${VERSION}..."
    $CMD --target=prod --build-arg PHP_VERSION=${VERSION} -t "${BASE_NAME}":"${VERSION}" -f ${DOCKER_FILE} ${ABSOLUTE_PATH} >> "${LOGFILE}"

    echo "Building ${VERSION}-ci..."
    ${CMD} --target=ci --build-arg PHP_VERSION=${VERSION} -t "${BASE_NAME}":"${VERSION}"-ci -f ${DOCKER_FILE} ${ABSOLUTE_PATH} >> "${LOGFILE}"
done

echo "Tagging latest from ${LATEST}..."
$CMD --target=prod --build-arg PHP_VERSION=${LATEST} -t "${BASE_NAME}":latest -f ${DOCKER_FILE} ${ABSOLUTE_PATH} >> "${LOGFILE}"
