#!/usr/bin/env bash

SVC_NAME=rabbit
NET_NAME=test

docker service rm "$SVC_NAME-1"
docker service rm "$SVC_NAME-2"
docker service rm "$SVC_NAME-3"
docker network rm $NET_NAME
