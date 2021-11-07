#!/bin/sh

DB_PASSWORD='pass'
DB_USER='app'
DB_CONTAINER_NAME='kittens-store-db'
APP_CONTAINER_NAME='kittens-store-app'
OPS_DIR_PATH="$(dirname "$BASH_SOURCE")"


is_container_running() {
  "$( docker container inspect -f '{{.State.Running}}' $1 )" == "true"
}

build_db_url() {
  db_host="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $DB_CONTAINER_NAME)"
  db_url="postgres://$DB_USER:$DB_PASSWORD@$db_host:5432"

  echo "$db_url"
}

spin_db_container() {
  echo '---- Spinning up db...'

  docker stop $DB_CONTAINER_NAME || true && docker rm $DB_CONTAINER_NAME || true

  docker run --name $DB_CONTAINER_NAME -d -p 5432:5432 -e POSTGRES_PASSWORD=$DB_PASSWORD -e POSTGRES_USER=$DB_USER postgres:14.0-alpine

  if is_container_running $DB_CONTAINER_NAME ; then
    echo "---- DB container is up. Container name: $DB_CONTAINER_NAME"
  else
    echo '---- Cannot spin db.'
  fi
}

spin_app_container() {
  echo '---- Spinning up app...'

  docker stop $APP_CONTAINER_NAME || true && docker rm $APP_CONTAINER_NAME || true

  docker build -f "$OPS_DIR_PATH/Dokerfile" -t kitten-store-app "$OPS_DIR_PATH/.."
  docker run --name $APP_CONTAINER_NAME -d -p 1234:1234 -e DATABASE_URL=$(build_db_url) kitten-store-app bundle exec rackup --port 1234 --host 0.0.0.0
  docker exec -d $APP_CONTAINER_NAME bundle exec rake db:create db:migrate db:seed

  if is_container_running $APP_CONTAINER_NAME ; then
    echo "---- App container is up. Container name: $APP_CONTAINER_NAME"
  else
    echo '---- Cannot spin app.'
  fi
}

spin_db_container
spin_app_container