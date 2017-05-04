FROM rabbitmq:management

COPY rabbitmq.config /etc/rabbitmq/rabbitmq.config
RUN chmod 777 /etc/rabbitmq/rabbitmq.config

ENV RABBITMQ_SETUP_DELAY=10
ENV RABBITMQ_USER user
ENV RABBITMQ_PASSWORD user
ENV RABBITMQ_CLUSTER_NODES=
ENV RABBITMQ_FIREHOSE_QUEUENAME=
ENV RABBITMQ_FIREHOSE_ROUTINGKEY=publish.#

RUN apt-get update -y && apt-get install -y python

ADD init.sh /init.sh
EXPOSE 15672

CMD ["/init.sh"]
