#!/usr/bin/env bash

echo "RABBITMQ_SETUP_DELAY                = ${RABBITMQ_SETUP_DELAY:=5}"
echo "RABBITMQ_USER                       = ${RABBITMQ_USER:=guest}"
echo "RABBITMQ_PASSWORD                   = ${RABBITMQ_PASSWORD:=guest}"
echo "RABBITMQ_LOOPBACK_USERS             = $RABBITMQ_LOOPBACK_USERS"
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
    ./rabbitmqadmin --username=$RABBITMQ_USER --password=$RABBITMQ_PASSWORD declare queue name=$RABBITMQ_FIREHOSE_QUEUENAME
    ./rabbitmqadmin --username=$RABBITMQ_USER --password=$RABBITMQ_PASSWORD list queues
    echo -n "Declaring binding from 'amq.rabbitmq.trace' to '$RABBITMQ_FIREHOSE_QUEUENAME' with '$RABBITMQ_FIREHOSE_ROUTINGKEY' routing key ... "
    ./rabbitmqadmin --username=$RABBITMQ_USER --password=$RABBITMQ_PASSWORD declare binding source=amq.rabbitmq.trace destination=$RABBITMQ_FIREHOSE_QUEUENAME routing_key=$RABBITMQ_FIREHOSE_ROUTINGKEY
    ./rabbitmqadmin --username=$RABBITMQ_USER --password=$RABBITMQ_PASSWORD list bindings
    rabbitmqctl trace_on
    echo "<< Enabling Firehose ... DONE >>>"
  fi
) & rabbitmq-server $@
