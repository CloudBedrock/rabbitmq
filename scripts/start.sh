#!/usr/bin/env bash

SVC_NAME=rabbit
NET_NAME=test
USER_NAME=admin
PASSWORD=admin
ERLANG_SECRET=secret
TRACE_QUEUE=trace
PORT=5672
MGMT_PORT=15672
DELAY=10

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
    -e RABBITMQ_SETUP_DELAY=$(($DELAY*3)) \
    -e RABBITMQ_USER=$USER_NAME \
    -e RABBITMQ_PASSWORD=$PASSWORD \
    -e RABBITMQ_CLUSTER_NODES="rabbit@$SVC_NAME-2 rabbit@$SVC_NAME-3" \
    -e RABBITMQ_NODENAME="rabbit@$SVC_NAME-1" \
    -e RABBITMQ_ERLANG_COOKIE=$ERLANG_SECRET \
    -e RABBITMQ_FIREHOSE_QUEUENAME=$TRACE_QUEUE \
    -e RABBITMQ_FIREHOSE_ROUTINGKEY=publish.# \
    kuznero/rabbitmq:management-cluster
fi

n=$(docker service ls --filter name=$SVC_NAME-2 | grep -v '^ID' | wc -l)
if [[ $n -eq 0 ]]; then
  docker service create \
    --name $SVC_NAME-2 \
    --network $NET_NAME \
    -p $(($PORT+1)):5672 \
    -p $(($MGMT_PORT+1)):15672 \
    -e RABBITMQ_SETUP_DELAY=$(($DELAY*2)) \
    -e RABBITMQ_USER=$USER_NAME \
    -e RABBITMQ_PASSWORD=$PASSWORD \
    -e RABBITMQ_CLUSTER_NODES="rabbit@$SVC_NAME-1 rabbit@$SVC_NAME-3" \
    -e RABBITMQ_NODENAME="rabbit@$SVC_NAME-2" \
    -e RABBITMQ_ERLANG_COOKIE=$ERLANG_SECRET \
    -e RABBITMQ_FIREHOSE_QUEUENAME=$TRACE_QUEUE \
    -e RABBITMQ_FIREHOSE_ROUTINGKEY=publish.# \
    kuznero/rabbitmq:management-cluster
fi

n=$(docker service ls --filter name=$SVC_NAME-3 | grep -v '^ID' | wc -l)
if [[ $n -eq 0 ]]; then
  docker service create \
    --name $SVC_NAME-3 \
    --network $NET_NAME \
    -p $(($PORT+2)):5672 \
    -p $(($MGMT_PORT+2)):15672 \
    -e RABBITMQ_SETUP_DELAY=$DELAY \
    -e RABBITMQ_USER=$USER_NAME \
    -e RABBITMQ_PASSWORD=$PASSWORD \
    -e RABBITMQ_CLUSTER_NODES="rabbit@$SVC_NAME-1 rabbit@$SVC_NAME-2" \
    -e RABBITMQ_NODENAME="rabbit@$SVC_NAME-3" \
    -e RABBITMQ_ERLANG_COOKIE=$ERLANG_SECRET \
    -e RABBITMQ_FIREHOSE_QUEUENAME=$TRACE_QUEUE \
    -e RABBITMQ_FIREHOSE_ROUTINGKEY=publish.# \
    kuznero/rabbitmq:management-cluster
fi

# echo -n "Waiting for nodes to establish cluster ... "
# sleep $(($DELAY*3))
# echo "done."
