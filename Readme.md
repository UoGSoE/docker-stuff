# Docker stuff

This is the base repo for our docker/swarm app configs.  Generic as far as possible for our Laravel/PHP apps and used as the base on new projects.  Ideally they can be used 'as is' outside of special-case apps.


## If you're interested

Each app gets a copy of the docker files (you can run `./copyto ../code/my-project` to copy them in).  The stack file
is pretty generic and used as the base for all our apps.  To use it you need to set a few environment variables and create a secret in swarm.  For instance, for an app called 'bingo' you might do :

```
# set some env variables
export PHP_VERSION=7.3
export IMAGE_NAME=127.0.0.1:5000/bingo
export TRAEFIK_BACKEND=bingo-web
export TRAEFIK_HOSTNAME=bingo.yourdomain.com
export DOTENV_NAME=bingo-dotenv-20190428

# enable docker buildkit
export DOCKER_BUILDKIT=1

# build the image and push to a local registry (with the 'production' target - there is a 'ci' for testing/qa too)
docker build --build-arg=PHP_VERSION=${PHP_VERSION} --target=prod -t ${IMAGE_NAME} .
docker push ${IMAGE_NAME}

# create a docker secret from a file called docker.env - this should be your normal production laravel app '.env' stuff
docker secret create ${DOTENV_NAME} docker.env

# and deploy
docker stack deploy -c prod-stack.yml bingo
```

There is a 'qa-stack.yml' which is more like the provided `docker-compose` setup in that it will spin-up a stand-alone mysql/redis/maihog for the app.

There is a `docker-compose.yml` file that you can use for dev/demo-ing.  It will use a local `.env` file as the laravel .env inside the containers.  You also need to set a couple of environment variables as above before starting it, specifically the `IMAGE_NAME`, and `APP_PORT` (the port the app will be available on - defaults to 3000).

The 'compose' version will run the app, and also a local copy of mysql and redis.  It will also spin up a copy of [Mailhog](https://github.com/mailhog/MailHog) to trap outgoing mail and make it available at http://localhost:3025.

```
# example for docker-compose
export PHP_VERSION=7.3  # only needed if you are building the image as part of this
export IMAGE_NAME=bingo:1.2.7
export APP_PORT=3002

docker-compose up --build
```

### Assumptions

You are using [Traefik](https://traefik.io/) as your proxy and there is a swarm overlay network for it called 'proxy'.

You have a mysql database server (or mysql-router) available in an overlay network called 'mysql' and it's docker container name is 'mysql'.

It defaults to doing a 'healthcheck' by making an http get request to '/' every 30 seconds.  If you want to use something else then change the curl command in `docker/app-healthcheck` and/or altering the HEALTHCHECK line in the Dockerfile.

You have an environment variable called PHP_VERSION that targets the major.minor version you are wanting to use, eg `export PHP_VERSION=7.3`.  The default PHP_VERSION is at the top of the dockerfile if you don't want to use an env variable.

### Base images

To build the base php images themselves we use the `build.sh` script and files inside the `base-images/` directory.

### Example dotenv that matches the stack

```
APP_NAME="Bingo"
APP_ENV=production
APP_KEY=base64:jxTSe1f8UnLnQWJyG0xMOQKnExy+MuXJLo6Yju/8iRM=
APP_DEBUG=false
APP_LOG_LEVEL=debug
APP_URL=http://bingo.yourdomain.com/

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=your_db_name
DB_USERNAME=your_db_user
DB_PASSWORD=your_db_password

BROADCAST_DRIVER=redis
CACHE_DRIVER=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120
QUEUE_CONNECTION=redis
QUEUE_NAME=bingo-queue

LOG_CHANNEL=errorlog

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_DRIVER=smtp
MAIL_HOST=smtp.yourdomain.com
MAIL_PORT=25
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=bingo-app@yourdomain.com
MAIL_FROM_NAME="Bingo App"

LDAP_SERVER=ldap.yourdomain.com
LDAP_OU=Users
LDAP_USERNAME='whatever'
LDAP_PASSWORD=secret

```

## Gitlab-ci

There's `.env.gitlab` and `.gitlab-ci.yml` files with the settings we use to run gitlab's CI process.  Feel free to steal them.  Our gitlab assumed you will have an environment variable set up in gitlab's CI settings for the php version you are targetting, eg `PHP_VERSION` `7.3`.  There are a few other variables you should set too - they are detailed at the top of the `.gitlab-ci.yml` file.

The gitlab CI setup will build two images :

* `your/repo:qa-${git_sha}` - all the code & prod+dev php packages
* `your/repo:prod-${git_sha}` - all the code & only production php packages (only built when pushing to the master branch)

## GitHub Actions
There's also a `.github` directory and a matching `.env.github` and `phpunit.gihub.xml` file for running tests and builds of docker images.  By default, the action run will do :

* any push to the repo will build a local image and run phpunit.
* If you push/merge to `master` it will also build & push an production image with `your/repo:prod-${git_sha}`
* If you push a git tag starting with `qa` (eg, `git tag -a qa-test-new-feature`) it will build and push a development/debug image named `your/repo:qa-test-new-feature`
* If you push a git tag starting with a `v` and a semver-looking value after it (eg, `git tag -a v1.2.3`) it will build and push a production image named `your/repo:v1.2.3` and also publish a github 'release' of `v1.2.3`.

Note that for the image pushes to work you need to define two secrets in your repo or organisation - `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.
## Our current setup

We have a small(ish) docker swarm.  Each node runs a local container registry on 127.0.0.1:5000.  We have an on-premise Gitlab install which acts as our source controller, CI runner and container registry.

All of the container registries are backed by 'S3'-alike storage provided using a local [Minio](https://www.minio.io/) server.  That means when we push an image to Gitlab, it ends
up being available on all of the swarm nodes too as they're all pointing at the same bucket.  That just means we avoid some tls/auth stuff - it's all on premise behind the corporate firewall - don't hate on me ;-)

The config to do that with the registry is just :

```
version: 0.1
log:
  level: debug
  formatter: text
  fields:
    service: registry
    environment: staging
loglevel: debug
http:
 secret: some-long-string
storage:
  s3:
    accesskey: some-other-string
    secretkey: an-even-longer-string
    region: us-east-1
    regionendpoint: http://our.minio.server:9000
    # Make sure you've created the following bucket.
    bucket: "docker-registry"
    encrypt: false
    secure: true
    v4auth: true
  delete:
    enabled: true
  maintenance:
    uploadpurging:
      enabled: true
      age: 168h
      interval: 24h
      dryrun: false
    readonly:
      enabled: false
http:
  addr: :5000
```

And the config for gitlab is just :

```
... your other config
registry['storage'] = {
  's3' => {
    'accesskey' => 'some-other-string',
    'secretkey' => 'an-even-longer-string',
    'bucket' => 'docker-registry',
    'regionendpoint' => 'http://our.minio.server:9000',
    'region' => 'us-east-1',
    'path_style' => true
  }
}
```
