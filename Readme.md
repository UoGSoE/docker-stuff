# Docker stuff

This is a WIP repo for our docker/swarm app configs.  Generic as far as possible for our
Laravel/PHP apps.

## If you're interested

Each app gets a copy of the `docker/` directory and the `stack.yml` file.  The stack file
is pretty generic and used for all our apps.  To use it you need to set a few environment variables and create a secret in swarm.  For instance, for an app called 'bingo' you might do :

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
