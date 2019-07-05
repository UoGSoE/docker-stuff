#!/bin/bash


BASE_NAME="uogsoe/soe-php-apache"
VERSIONS=( "7.1" "7.2" "7.3" )
CMD="docker buildx build --pull --push --no-cache --platform linux/amd64,linux/arm/v7" 
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
    $CMD --target=prod --build-arg PHP_VERSION=${VERSION} -t "${BASE_NAME}":"${VERSION}" -f Dockerfile.base . >> "${LOGFILE}"

    echo "Building ${VERSION}-ci..."
    ${CMD} --target=ci --build-arg PHP_VERSION=${VERSION} -t "${BASE_NAME}":"${VERSION}"-ci -f Dockerfile.base . >> "${LOGFILE}"
done

