# RabbitMQ cluster

## Available images

* `kuznero/rabbitmq:3.6.10-mancluster` - following official
  `rabbitmq:3.6.10-management`.

## Setting up RabbitMQ cluster in Docker Swarm (Mode)

Official [clustering guidelines](https://www.rabbitmq.com/clustering.html)
suggest that there are a few ways to create RabbitMQ cluster. There are also
options that will allow creating clusters that could discover its nodes
automatically through some discovery service like Etcs or Consul.

> Due to the fact that our runtime environment is Docker Swarm where we will
  need to mount volumes to ensure that data is getting persisted and not lost
  over the course of RabbitMQ upgrade or a restart. For us it was proven to be
  highly problemmatic to make sure that new instances of RabbitMQ cluster get
  mounted to the same mount points and in the same time recognize new cluster
  configuration (since after restart all RabbitMQ nodes will have new
  hostnames while e.g. Consul still have an understanding of a cluster with old
  hostnames). There might be a solution to this which we would like to know
  about. So, if you are willing to contribute, please send us your pull request.

What this project attempts to do is to create a declarative approach to defining
RabbitMQ cluster i.e. define nodes that needs to be descovered on startup of
docker image.

Parameters that can control how exactly RabbitMQ is going to be configured are
here:

* `RABBITMQ_USER` - new user name
* `RABBITMQ_PASSWORD` - password for new user
* `RABBITMQ_LOOPBACK_USERS` - a space delimited list of users considered to be
  loopback users (users that are allowed to connect to RabbitMQ only through
  `localhost` address).
* `RABBITMQ_CLUSTER_NODES` - a space delimited list of RabbitMQ
  nodes that it needs to connect to (`join_cluster`), e.g.
  `"rabbit@rabbit-1 rabbit@rabbit-2 rabbit@rabbit-3"`.
* `RABBITMQ_CLUSTER_PARTITION_HANDLING` can be one of `ignore`, `pause_minority`
  or `autoheal`.
* `RABBITMQ_CLUSTER_DISC_RAM` can be one of `disc` or `ram`.
* `RABBITMQ_HIPE_COMPILE` can be either `false` or `true`.
* `RABBITMQ_NODENAME` should have a value in the form `rabbit@short-host-name`.
* `RABBITMQ_FIREHOSE_QUEUENAME` - queue name for
  **Firehose** tracing (if it is left blank **Firehose** will not be
  enabled)
* `RABBITMQ_FIREHOSE_ROUTINGKEY` - routing key that will be
  used to mount `amq.rabbitmq.trace` exchange with queue (name for
  which can be defined with `RABBITMQ_FIREHOSE_QUEUENAME`
  environment variable). The default value for it is `publish.#`.

Here is how we will do this (`Dockerfile`):

```{.Dockerfile}
FROM rabbitmq:3.6.10-management

COPY rabbitmq.config /etc/rabbitmq/rabbitmq.config
RUN chmod 777 /etc/rabbitmq/rabbitmq.config

ENV RABBITMQ_SETUP_DELAY=5
ENV RABBITMQ_USER=guest
ENV RABBITMQ_PASSWORD=guest
ENV RABBITMQ_LOOPBACK_USERS=guest
ENV RABBITMQ_CLUSTER_NODES=
ENV RABBITMQ_CLUSTER_PARTITION_HANDLING=autoheal
ENV RABBITMQ_CLUSTER_DISC_RAM=disc
ENV RABBITMQ_FIREHOSE_QUEUENAME=
ENV RABBITMQ_FIREHOSE_ROUTINGKEY=publish.#
ENV RABBITMQ_HIPE_COMPILE=false
ENV RABBITMQ_NODENAME=

RUN apt-get update -y && apt-get install -y python

ADD init.sh /init.sh
EXPOSE 15672

CMD ["/init.sh"]
```

We are taking our own `rabbitmq.config` file that has only one
important bits:

```{.erlang}
%% -*- mode: erlang -*-
[
 {rabbit,
  [
   {cluster_partition_handling, [[CLUSTER_PARTITION_HANDLING]]},
   {cluster_nodes, {[[[CLUSTER_NODES]]], [[CLUSTER_DISC_RAM]]}},
   {default_vhost, <<"/">>},
   {default_user, <<"[[USER]]">>},
   {default_pass, <<"[[PASSWORD]]">>},
   {default_permissions, [<<".*">>, <<".*">>, <<".*">>]},
   {default_user_tags, [administrator, management]},
   {hipe_compile, [[HIPE_COMPILE]]},
   {loopback_users, [[[LOOPBACK_USERS]]]},
   {mnesia_table_loading_retry_limit, 10},
   {mnesia_table_loading_retry_timeout, 30000}
   % {log_levels, [{connection, channel, federation, mirroring, debug}]}
  ]}
].
```

> Note that placeholder in the form `[[PLACEHOLDER]]` will be replaced right
> before container starts filling respective values from environment variables
> passed to it.

And we change our entry point to our own script where we can pre-configure a lot
of things (for that reason we needed to have `python` installed as
part of our image):

```{.bash}
#!/usr/bin/env bash

echo "RABBITMQ_SETUP_DELAY                = ${RABBITMQ_SETUP_DELAY:=5}"
echo "RABBITMQ_USER                       = ${RABBITMQ_USER:=guest}"
echo "RABBITMQ_PASSWORD                   = ${RABBITMQ_PASSWORD:=guest}"
echo "RABBITMQ_LOOPBACK_USERS             = RABBITMQ_LOOPBACK_USERS"
echo "RABBITMQ_CLUSTER_NODES              = $RABBITMQ_CLUSTER_NODES"
echo "RABBITMQ_CLUSTER_PARTITION_HANDLING = ${RABBITMQ_CLUSTER_PARTITION_HANDLING:=autoheal}"
echo "RABBITMQ_CLUSTER_DISC_RAM           = ${RABBITMQ_CLUSTER_DISC_RAM:=disc}"
echo "RABBITMQ_FIREHOSE_QUEUENAME         = $RABBITMQ_FIREHOSE_QUEUENAME"
echo "RABBITMQ_FIREHOSE_ROUTINGKEY        = $RABBITMQ_FIREHOSE_ROUTINGKEY"
echo "RABBITMQ_HIPE_COMPILE               = ${RABBITMQ_HIPE_COMPILE:=false}"
echo "RABBITMQ_NODENAME                   = $RABBITMQ_NODENAME"

CONFIG=/etc/rabbitmq/rabbitmq.config

nodes_list=""
IFS=' '; read -ra nodes <<< "$RABBITMQ_CLUSTER_NODES"
for node in "${nodes[@]}"; do
  nodes_list="$nodes_list, '$node'"
done
nodes_list=${nodes_list:2}

lbusers_list=""
IFS=' '; read -ra lbusers <<< "$RABBITMQ_LOOPBACK_USERS"
for lbuser in "${lbusers[@]}"; do
  lbusers_list="$lbusers_list, <<\"$lbuser\">>"
done
lbusers_list=${lbusers_list:2}

sed -i "s/\[\[CLUSTER_PARTITION_HANDLING\]\]/$RABBITMQ_CLUSTER_PARTITION_HANDLING/" $CONFIG
sed -i "s/\[\[CLUSTER_NODES\]\]/$nodes_list/" $CONFIG
sed -i "s/\[\[CLUSTER_DISC_RAM\]\]/$RABBITMQ_CLUSTER_DISC_RAM/" $CONFIG
sed -i "s/\[\[HIPE_COMPILE\]\]/$RABBITMQ_HIPE_COMPILE/" $CONFIG
sed -i "s/\[\[USER\]\]/$RABBITMQ_USER/" $CONFIG
sed -i "s/\[\[PASSWORD\]\]/$RABBITMQ_PASSWORD/" $CONFIG
sed -i "s/\[\[LOOPBACK_USERS\]\]/$lbusers_list/" $CONFIG

echo "<< RabbitMQ.config ... >>>"
cat $CONFIG
echo "<< RabbitMQ.config >>>"

(
  sleep ${RABBITMQ_SETUP_DELAY:-5}

  rabbitmqctl set_policy SyncQs '.*' '{"ha-mode":"all","ha-sync-mode":"automatic"}' --priority 0 --apply-to queues
  if [[ "$RABBITMQ_FIREHOSE_QUEUENAME" != "" ]]; then
    echo "<< Enabling Firehose ... >>>"
    ln -s $(find -iname rabbitmqadmin | head -1) /rabbitmqadmin
    chmod +x /rabbitmqadmin
    echo -n "Declaring '$RABBITMQ_FIREHOSE_QUEUENAME' queue ... "
    ./rabbitmqadmin declare queue name=$RABBITMQ_FIREHOSE_QUEUENAME
    ./rabbitmqadmin list queues
    echo -n "Declaring binding from 'amq.rabbitmq.trace' to '$RABBITMQ_FIREHOSE_QUEUENAME' with '$RABBITMQ_FIREHOSE_ROUTINGKEY' routing key ... "
    ./rabbitmqadmin declare binding source=amq.rabbitmq.trace destination=$RABBITMQ_FIREHOSE_QUEUENAME routing_key=$RABBITMQ_FIREHOSE_ROUTINGKEY
    ./rabbitmqadmin list bindings
    rabbitmqctl trace_on
    echo "<< Enabling Firehose ... DONE >>>"
  fi
) & rabbitmq-server $@
```

> Notice that by default we create `SyncQs` policy that will
  automatically synchronize queues across all cluster nodes.

> `RABBITMQ_SETUP_DELAY` (in seconds) is used here to make sure setup process
> starts when RabbitMQ server had started (typically a small value, like 5
> seconds).

## Configuring persistence layer

Let's now setup persistence layer such that after RabbitMQ restart data stays
intact. Since we are currently running 3 instances of RabbitMQ, we will need to
also create target folder for mount point that is going to be used by RabbitMQ
server (let's say on `SERVER1`, `SERVER3` and
`SERVER5`):

* On `SERVER1`: `$ mkdir -p /data/rabbitmq-1`
* On `SERVER3`: `$ mkdir -p /data/rabbitmq-2`
* On `SERVER5`: `$ mkdir -p /data/rabbitmq-3`

Then, we need to label our swarm cluster nodes appropriately.

```{.bash}
$ docker node ls
ID                           HOSTNAME  STATUS  AVAILABILITY  MANAGER
6so183185g8qd11aoix21rea1    SERVER5    Ready   Active        Reachable
920kij34jhrz76lprdthz2utz    SERVER3    Ready   Active        Reachable
9zlzpsto6m4f9h0inilgy2hkr    SERVER4    Ready   Active        Reachable
au00yheo9dvstjwvk3lo4l2oe *  SERVER1    Ready   Active        Reachable
c7n1elqonzsidncwlyg62d90v    SERVER2    Ready   Active        Leader

$ docker node update --label-add rabbitmq-1=on au00yheo9dvstjwvk3lo4l2oe
$ docker node update --label-add rabbitmq-2=on 920kij34jhrz76lprdthz2utz
$ docker node update --label-add rabbitmq-3=on 6so183185g8qd11aoix21rea1
```

It is possible to see that label has been correctly set by invoking following
command:

```{.bash}
$ docker node inspect au00yheo9dvstjwvk3lo4l2oe
$ docker node inspect 920kij34jhrz76lprdthz2utz
$ docker node inspect 6so183185g8qd11aoix21rea1
```

> This will produce relatively big output, you will need to inspect
  `Spec > Labels` part of it.

And now, after we have configured our labels and created folder for mount point,
we can revisit service creation instructions for e.g. 3-noded RabbitMQ cluster:

```{.bash}
$ docker service create \
    --name rabbit-1 \
    --network net \
    --constraint node.labels.rabbitmq-1==on \
    --mount type=bind,source=/data/rabbitmq-1,target=/var/lib/rabbitmq \
    -e RABBITMQ_SETUP_DELAY=15 \
    -e RABBITMQ_USER=admin \
    -e RABBITMQ_PASSWORD=adminpwd \
    -e RABBITMQ_CLUSTER_NODES='rabbit@rabbit-1 rabbit@rabbit-2 rabbit@rabbit-3' \
    -e RABBITMQ_CLUSTER_PARTITION_HANDLING=autoheal \
    -e RABBITMQ_CLUSTER_DISC_RAM=disc \
    -e RABBITMQ_NODENAME=rabbit@rabbit-1 \
    -e RABBITMQ_ERLANG_COOKIE=a-little-secret \
    -e RABBITMQ_FIREHOSE_QUEUENAME=trace \
    -e RABBITMQ_FIREHOSE_ROUTINGKEY=publish.# \
    -e RABBITMQ_HIPE_COMPILE=true \
    kuznero/rabbitmq:3.6.10-mancluster

$ docker service create \
    --name rabbit-2 \
    --network net \
    --constraint node.labels.rabbitmq-2==on \
    --mount type=bind,source=/data/rabbitmq-2,target=/var/lib/rabbitmq \
    -e RABBITMQ_SETUP_DELAY=10 \
    -e RABBITMQ_USER=admin \
    -e RABBITMQ_PASSWORD=adminpwd \
    -e RABBITMQ_CLUSTER_NODES='rabbit@rabbit-1 rabbit@rabbit-2 rabbit@rabbit-3' \
    -e RABBITMQ_CLUSTER_PARTITION_HANDLING=autoheal \
    -e RABBITMQ_CLUSTER_DISC_RAM=disc \
    -e RABBITMQ_NODENAME=rabbit@rabbit-2 \
    -e RABBITMQ_ERLANG_COOKIE=a-little-secret \
    -e RABBITMQ_FIREHOSE_QUEUENAME=trace \
    -e RABBITMQ_FIREHOSE_ROUTINGKEY=publish.# \
    -e RABBITMQ_HIPE_COMPILE=true \
    kuznero/rabbitmq:3.6.10-mancluster

$ docker service create \
    --name rabbit-3 \
    --network net \
    --constraint node.labels.rabbitmq-3==on \
    --mount type=bind,source=/data/rabbitmq-3,target=/var/lib/rabbitmq \
    -e RABBITMQ_SETUP_DELAY=5 \
    -e RABBITMQ_USER=admin \
    -e RABBITMQ_PASSWORD=adminpwd \
    -e RABBITMQ_CLUSTER_NODES='rabbit@rabbit-1 rabbit@rabbit-2 rabbit@rabbit-3' \
    -e RABBITMQ_CLUSTER_PARTITION_HANDLING=autoheal \
    -e RABBITMQ_CLUSTER_DISC_RAM=disc \
    -e RABBITMQ_NODENAME=rabbit@rabbit-3 \
    -e RABBITMQ_ERLANG_COOKIE=a-little-secret \
    -e RABBITMQ_FIREHOSE_QUEUENAME=trace \
    -e RABBITMQ_FIREHOSE_ROUTINGKEY=publish.# \
    -e RABBITMQ_HIPE_COMPILE=true \
    kuznero/rabbitmq:3.6.10-mancluster
```

> This will start 3 different services (single replica services).

> This setup will reliably reconnect restarted node into a cluster!

## Considerations for delivery pipeline for RabbitMQ cluster

All nodes of RabbitMQ cluster must run same version of RabbitMQ and OTP. That
enforces some limitations onto how it is possible to perform upgrades.
The only option for RabbitMQ cluster upgrade is during non-working hours when
there is no activity such that it is possible to bring whole cluster down and
upgrade it.

## Testing

> For testing purposes there are `start.sh` and `stop.sh` scripts included under
> `./scripts` folder that is possible to use for running small 3-noded RabbitMQ
> cluster on a local (possible single noded) docker swarm cluster.
