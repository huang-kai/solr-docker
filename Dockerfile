FROM    java:openjdk-8-jre
MAINTAINER  Kyne Huang <kyne.huang@hujiang.com>
ENV REFRESHED_AT 2015-12-2

RUN apt-get update && \
  apt-get -y install lsof unzip && \
  rm -rf /var/lib/apt/lists/*

ENV SOLR_USER solr
ENV SOLR_UID 8983

RUN groupadd -r $SOLR_USER && \
  useradd -r -u $SOLR_UID -g $SOLR_USER $SOLR_USER

ENV SOLR_KEY CFCE5FBB920C3C745CEEE084C38FF5EC3FCFDB3E
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$SOLR_KEY"

ENV SOLR_VERSION 5.3.1
ENV SOLR_SHA256 34ddcac071226acd6974a392af7671f687990aa1f9eb4b181d533ca6dca6f42d

RUN mkdir -p /opt/solr && \
  wget -nv --output-document=/opt/solr.tgz http://mirrors.hust.edu.cn/apache/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz && \
  wget -nv --output-document=/opt/solr.tgz.asc http://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz.asc && \
  gpg --verify /opt/solr.tgz.asc && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  mkdir -p /opt/solr/server/solr/lib && \
  chown -R $SOLR_USER:$SOLR_USER /opt/solr

# https://issues.apache.org/jira/browse/SOLR-8107
RUN sed --in-place -e 's/^    "$JAVA" "${SOLR_START_OPTS\[@\]}" $SOLR_ADDL_ARGS -jar start.jar "${SOLR_JETTY_CONFIG\[@\]}"/    exec "$JAVA" "${SOLR_START_OPTS[@]}" $SOLR_ADDL_ARGS -jar start.jar "${SOLR_JETTY_CONFIG[@]}"/' /opt/solr/bin/solr

#Link to Consul Template Binary
ADD https://releases.hashicorp.com/consul-template/0.11.1/consul-template_0.11.1_linux_amd64.zip /tmp/consul-template.zip
#Install Consul Template
RUN cd /usr/sbin && unzip /tmp/consul-template.zip && chmod +x /usr/sbin/consul-template && rm /tmp/consul-template.zip
#Setup Consul Template Files
RUN mkdir /etc/consul-templates
ENV CT_FILE /etc/consul-templates/solr.in.sh.ctmpl
ENV SOLR_CONF_FILE /opt/solr/bin/solr.in.sh
ADD solr.in.sh.ctmpl $CT_FILE

#Default Variables
ENV CONSUL localhost:8500
ENV SERVICE zookeeper

VOLUME ["/opt/solr/server/solr/data"]
EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

#CMD /opt/solr/bin/solr restart
CMD consul-template \
    -log-level debug \
    -consul $CONSUL \
    -template "$CT_FILE:$SOLR_CONF_FILE:/opt/solr/bin/solr restart $MESOS_CONTAINER_NAME &"
#    -wait 90s
