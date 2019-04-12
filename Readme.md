# Docker stuff

This is a WIP repo for our docker/swarm app configs.  Generic as far as possible for our
Laravel/PHP apps.

## If you're interested

Each app gets a copy of the `docker/` directory and the `stack.yml` file.  The stack file
is pretty generic and used as the base for all our apps.  To use it you need to set a few environment variables and create a secret in swarm.  For instance, for an app called 'bingo' you might do :

```
# build the image and push to a local registry
docker build -t 127.0.0.1:5000/bingo -f ./docker/prod.Dockerfile .
docker push 127.0.0.1:5000/bingo

# create a docker secret from a file called docker.env - this should be your normal laravel app '.env' stuff
docker secret create bingo-dotenv-20190428 docker.env

# set the deployment environment variables
export IMAGE_NAME=127.0.0.1:5000/bingo
export TRAEFIK_BACKEND=bingo-web
export TRAEFIK_HOSTNAME=bingo.yourdomain.com
export DOTENV_NAME=bingo-dotenv-20190428

# and deploy
docker stack deploy -c stack.yml bingo
```

### Assumptions

You are using [Traefik](https://traefik.io/) as your proxy and there is a swarm overlay network for it called 'proxy'.

You have a mysql database server (or mysql-router) available in an overlay network called 'mysql' and it's docker container name is 'mysql'.

You have an http get endpoint in your main app available at `/login` - this is used as the healthcheck for the container.  If you want to use something else then change the curl command in `docker/app-healthcheck`.

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

There's a `gitlab/` folder with the scripts/files we use to run gitlab's CI process.  Feel free to steal them.  They need to to in the root directory of your repo for gitlab to pick them up.
