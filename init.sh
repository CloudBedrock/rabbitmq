#!/usr/bin/env bash

echo "RABBITMQ_SETUP_DELAY                = $RABBITMQ_SETUP_DELAY"
echo "RABBITMQ_USER                       = $RABBITMQ_USER"
echo "RABBITMQ_PASSWORD                   = $RABBITMQ_PASSWORD"
echo "RABBITMQ_CLUSTER_NODES              = $RABBITMQ_CLUSTER_NODES"
echo "RABBITMQ_CLUSTER_PARTITION_HANDLING = $RABBITMQ_CLUSTER_PARTITION_HANDLING"
echo "RABBITMQ_CLUSTER_DISC_RAM           = $RABBITMQ_CLUSTER_DISC_RAM"
echo "RABBITMQ_FIREHOSE_QUEUENAME         = $RABBITMQ_FIREHOSE_QUEUENAME"
echo "RABBITMQ_FIREHOSE_ROUTINGKEY        = $RABBITMQ_FIREHOSE_ROUTINGKEY"

nodes_list=""
IFS=' '; read -ra nodes <<< "$RABBITMQ_CLUSTER_NODES"
for node in "${nodes[@]}"; do
  nodes_list=", '$node'"
done
nodes_list=${nodes_list:2}

sed -i "s/[[CLUSTER_PARTITION_HANDLING]]/$RABBITMQ_CLUSTER_PARTITION_HANDLING/" /etc/rabbitmq/rabbitmq.config
sed -i "s/[[CLUSTER_NODES]]/$nodes_list/" /etc/rabbitmq/rabbitmq.config
sed -i "s/[[CLUSTER_DISC_RAM]]/$RABBITMQ_CLUSTER_DISC_RAM/" /etc/rabbitmq/rabbitmq.config
sed -i "s/[[USER]]/$RABBITMQ_USER/" /etc/rabbitmq/rabbitmq.config
sed -i "s/[[PASSWORD]]/$RABBITMQ_PASSWORD/" /etc/rabbitmq/rabbitmq.config

(
  sleep $RABBITMQ_SETUP_DELAY

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
