#!/bin/bash
set -e

# Hint: /etc/influxdb2 is empty in the container, so no .conf file there

HOST_FILES=/home/dockerfiles/influxdb_test  # _test or _prod, can't be on a system disk with Ubuntu snap docker
VERSION=2.1.1  # check https://portal.influxdata.com/downloads/ for the latest OSS version

VISIBLE_IP=64.13.139.229

DOCKER_NAME=influxdb_test  # _test or _prod
VISIBLE_PORT=8086  # 8086 for test, 8087 for prod; docker side is always 8086
PORTS="-p $VISIBLE_IP:$VISIBLE_PORT:8086 -p 127.0.0.1:$VISIBLE_PORT:8086"  # localhost required for CLI
ORG="eht"
BUCKET="eht_test"  # _test or _prod

CONFIG_NAME=config.yml
INFLUX_CONTAINER_USER=1000:1000  # this is baked into the container; consider mimicing this in the host
EXTRA=--reporting-disabled  # do not phone home

if [ -e $HOST_FILES/$CONFIG_NAME ]; then
   echo config file $HOST_FILES/$CONFIG_NAME already exists, exiting
   exit 1
fi

# there is another configuration file, ~/.influxdbv2/configs or INFLUX_CONFIGS_PATH
CHECK_CONF=${INFLUX_CONFIGS_PATH- ~/.influxdbv2/configs}
if [ -e $CHECK_CONF ]; then
    echo checking $CHECK_CONF for a duplicate config
    if [ grep $DOCKER_NAME $CHECK_CONF ]; then
    fi
fi


echo mkdir -p $HOST_FILES
mkdir -p $HOST_FILES
echo adjusting ownership
chown -R $INFLUX_CONTAINER_USER $HOST_FILES

echo making config file $CONFIG_NAME
docker run --rm influxdb:$VERSION influxd print-config > $HOST_FILES/$CONFIG_NAME

echo creating the instance with full configuration
docker run -d --name $DOCKER_NAME $PORTS --user $INFLUX_CONTAINER_USER --volume $HOST_FILES:/var/lib/influxdb2 influxdb:$VERSION $EXTRA

echo stopping docker instance to edit $CONFIG_NAME
docker stop $DOCKER_NAME

echo editing $HOST_FILES/$CONFIG_NAME to change storage-wal-fsync-delay to 14 seconds
cat $HOST_FILES/$CONFIG_NAME | sed s/storage-wal-fsync-delay: 0s/storage-wal-fsync-delay: 14s/ > $HOST_FILES/$CONFIG_NAME.new
mv $HOST_FILES/$CONFIG_NAME.new $HOST_FILES/$CONFIG_NAME

echo restarting $DOCKER_NAME
docker start $DOCKER_NAME

read_secret()
{
    trap 'stty echo' EXIT  # restores echo if user types ^C
    stty -echo
    read "$@"
    stty echo
    trap - EXIT
    echo
}

echo admin password:
read_secret password

ARGS=""
ARGS="$ARGS --host http://$VISIBLE_IP:$VISIBLE_PORT"
ARGS="$ARGS --username admin"
ARGS="$ARGS --password $password"
ARGS="$ARGS --org $ORG"
ARGS="$ARGS --bucket $BUCKET"
ARGS="$ARGS --rentention 0"
ARGS="$ARGS --force"
ARGS="$ARGS --name $DOCKER_NAME"

echo influx setup $ARGS
influx setup $ARGS
