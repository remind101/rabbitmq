FROM debian:wheezy

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r rabbitmq && useradd -r -d /var/lib/rabbitmq -m -g rabbitmq rabbitmq

RUN apt-get update && apt-get install -y curl ca-certificates --no-install-recommends && rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.6/gosu-$(dpkg --print-architecture)" \
	&& curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.6/gosu-$(dpkg --print-architecture).asc" \
	&& gpg --verify /usr/local/bin/gosu.asc \
	&& rm /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu

# get logs to stdout (thanks @dumbbell for pushing this upstream! :D)
ENV RABBITMQ_LOGS=- RABBITMQ_SASL_LOGS=-

ENV ERLANG_VERSION 17.5.3
ENV ERLANG_DEBIAN_VERSION 17.5.3-1

RUN apt-get update
RUN curl -L https://packages.erlang-solutions.com/erlang/esl-erlang/FLAVOUR_1_general/esl-erlang_${ERLANG_DEBIAN_VERSION}~debian~wheezy_amd64.deb > /tmp/erlang.deb
RUN dpkg -i /tmp/erlang.deb; apt-get install -yf
RUN dpkg -i /tmp/erlang.deb

ENV RABBITMQ_VERSION 3.5.7
ENV RABBITMQ_DEBIAN_VERSION 3.5.7-1

RUN curl -L https://www.rabbitmq.com/releases/rabbitmq-server/v${RABBITMQ_VERSION}/rabbitmq-server_${RABBITMQ_DEBIAN_VERSION}_all.deb > /tmp/rabbit.deb
RUN dpkg -i /tmp/rabbit.deb; apt-get install -yf
RUN dpkg -i /tmp/rabbit.deb

# /usr/sbin/rabbitmq-server has some irritating behavior, and only exists to "su - rabbitmq /usr/lib/rabbitmq/bin/rabbitmq-server ..."
ENV PATH /usr/lib/rabbitmq/bin:$PATH

RUN echo '[{rabbit, [{loopback_users, []}]}].' > /etc/rabbitmq/rabbitmq.config

VOLUME /var/lib/rabbitmq

# add a symlink to the .erlang.cookie in /root so we can "docker exec rabbitmqctl ..." without gosu
RUN ln -sf /var/lib/rabbitmq/.erlang.cookie /root/

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

RUN rabbitmq-plugins enable --offline rabbitmq_management

EXPOSE 4369 5671 5672 25672 15671 15672
CMD ["rabbitmq-server"]
