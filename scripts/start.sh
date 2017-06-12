#!/usr/bin/env bash

function usage() {
  echo "Expected arguments are missing: IMAGE_NAME"
}

if [[ "$#" -ne 1 ]]; then
  usage
  exit 1
fi

IMAGE_NAME=$1

NET_NAME=test
USER=guest
PASSWORD=guest
ERLANG_SECRET=secret
PORT=5672
MGMT_PORT=15672
SVC_NAME=rabbit
PARTITION_HANDLING=autoheal
DISC_RAM=ram
TRACE_QUEUE=
HIPE_COMPILE=false

DELAY=5

n=$(docker network ls --filter name=$NET_NAME | grep -v '^NETWORK' | wc -l)
if [[ $n -eq 0 ]]; then
  docker network create -d overlay $NET_NAME
fi

n=$(docker service ls --filter name=$SVC_NAME-1 | grep -v '^ID' | wc -l)
if [[ $n -eq 0 ]]; then
  docker service create \
    --name $SVC_NAME-1 \
    --network $NET_NAME \
    -p $PORT:5672 \
    -p $MGMT_PORT:15672 \
    -e RABBITMQ_SETUP_DELAY=$DELAY \
    -e RABBITMQ_USER=$USER \
    -e RABBITMQ_PASSWORD=$PASSWORD \
    -e RABBITMQ_LOOPBACK_USERS= \
    -e RABBITMQ_CLUSTER_NODES="rabbit@$SVC_NAME-1 rabbit@$SVC_NAME-2 rabbit@$SVC_NAME-3" \
    -e RABBITMQ_CLUSTER_PARTITION_HANDLING=$PARTITION_HANDLING \
    -e RABBITMQ_CLUSTER_DISC_RAM=$DISC_RAM \
    -e RABBITMQ_HIPE_COMPILE=$HIPE_COMPILE \
    -e RABBITMQ_NODENAME="rabbit@$SVC_NAME-1" \
    -e RABBITMQ_ERLANG_COOKIE=$ERLANG_SECRET \
    -e RABBITMQ_FIREHOSE_QUEUENAME=$TRACE_QUEUE \
    -e RABBITMQ_FIREHOSE_ROUTINGKEY=publish.# \
    --mount type=volume,source=$SVC_NAME-1,destination=/var/lib/rabbitmq \
    $IMAGE_NAME
fi

n=$(docker service ls --filter name=$SVC_NAME-2 | grep -v '^ID' | wc -l)
if [[ $n -eq 0 ]]; then
  docker service create \
    --name $SVC_NAME-2 \
    --network $NET_NAME \
    -p $(($PORT+1)):5672 \
    -p $(($MGMT_PORT+1)):15672 \
    -e RABBITMQ_SETUP_DELAY=$DELAY \
    -e RABBITMQ_USER=$USER \
    -e RABBITMQ_PASSWORD=$PASSWORD \
    -e RABBITMQ_LOOPBACK_USERS= \
    -e RABBITMQ_CLUSTER_NODES="rabbit@$SVC_NAME-1 rabbit@$SVC_NAME-2 rabbit@$SVC_NAME-3" \
    -e RABBITMQ_CLUSTER_PARTITION_HANDLING=$PARTITION_HANDLING \
    -e RABBITMQ_CLUSTER_DISC_RAM=$DISC_RAM \
    -e RABBITMQ_HIPE_COMPILE=$HIPE_COMPILE \
    -e RABBITMQ_NODENAME="rabbit@$SVC_NAME-2" \
    -e RABBITMQ_ERLANG_COOKIE=$ERLANG_SECRET \
    -e RABBITMQ_FIREHOSE_QUEUENAME=$TRACE_QUEUE \
    -e RABBITMQ_FIREHOSE_ROUTINGKEY=publish.# \
    --mount type=volume,source=$SVC_NAME-2,destination=/var/lib/rabbitmq \
    $IMAGE_NAME
fi

n=$(docker service ls --filter name=$SVC_NAME-3 | grep -v '^ID' | wc -l)
if [[ $n -eq 0 ]]; then
  docker service create \
    --name $SVC_NAME-3 \
    --network $NET_NAME \
    -p $(($PORT+2)):5672 \
    -p $(($MGMT_PORT+2)):15672 \
    -e RABBITMQ_SETUP_DELAY=$DELAY \
    -e RABBITMQ_USER=$USER \
    -e RABBITMQ_PASSWORD=$PASSWORD \
    -e RABBITMQ_LOOPBACK_USERS= \
    -e RABBITMQ_CLUSTER_NODES="rabbit@$SVC_NAME-1 rabbit@$SVC_NAME-2 rabbit@$SVC_NAME-3" \
    -e RABBITMQ_CLUSTER_PARTITION_HANDLING=$PARTITION_HANDLING \
    -e RABBITMQ_CLUSTER_DISC_RAM=$DISC_RAM \
    -e RABBITMQ_HIPE_COMPILE=$HIPE_COMPILE \
    -e RABBITMQ_NODENAME="rabbit@$SVC_NAME-3" \
    -e RABBITMQ_ERLANG_COOKIE=$ERLANG_SECRET \
    -e RABBITMQ_FIREHOSE_QUEUENAME=$TRACE_QUEUE \
    -e RABBITMQ_FIREHOSE_ROUTINGKEY=publish.# \
    --mount type=volume,source=$SVC_NAME-3,destination=/var/lib/rabbitmq \
    $IMAGE_NAME
fi
