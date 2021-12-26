#!/bin/bash
set -e

# Hint: /etc/influxdb2 is empty in the container, so no .conf file there

DOCKER_NAME=influxdb_test  # _test or _prod
HOST_FILES=/home/dockerfiles/influxdb_test  # _test or _prod, can't be on a system disk with Ubuntu snap docker
VERSION=2.1.1  # check https://portal.influxdata.com/downloads/ for the latest OSS version

VISIBLE_IP=64.13.139.229
VISIBLE_PORT=8086  # 8086 for test, 8087 for prod; docker side is always 8086
PORTS="-p $VISIBLE_IP:$VISIBLE_PORT:8086 -p 127.0.0.1:$VISIBLE_PORT:8086"  # localhost required for CLI

CONFIG_NAME=config.yml
INFLUX_CONTAINER_USER=1000:1000  # this is baked into the container; consider mimicing this in the host
EXTRA=--reporting-disabled  # do not phone home

if [ -e $HOST_FILES/$CONFIG_NAME ]; then
   echo config file $HOST_FILES/$CONFIG_NAME already exists, exiting
   exit 1
fi

mkdir -p $HOST_FILES

echo making config file $CONFIG_NAME
docker run --rm influxdb:$VERSION influxd print-config > $HOST_FILES/$CONFIG_NAME

echo creating the instance with full configuration
docker run -d --name $DOCKER_NAME $PORTS --user $INFLUX_CONTAINER_USER --volume $HOST_FILES:/var/lib/influxdb2 influxdb:$VERSION $EXTRA

echo stopping this instance so you can edit config.yml
docker stop $DOCKER_NAME

echo in the future this instance can start with a simple "'docker start $DOCKERNAME'"

echo now run "'influx setup'"

