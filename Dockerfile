FROM debian:9-slim

LABEL Maintainer="Ernesto Pérez <eperez@isotrol.com>" \
      Name="Docker Aptly" \
      Description="Imágen con el servicio aptly api" \
      Version="0.2.0"

RUN set -x \
    && sed -i -- 's/main/main contrib non-free/g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y \
    gnupg \
    ca-certificates \
    graphviz \
    curl \
    dirmngr

RUN set -x \
    && echo "deb http://repo.aptly.info/ squeeze main" \
     > /etc/apt/sources.list.d/aptly.list \
    && apt-key adv --keyserver hkp://keys.gnupg.net:80 --keyserver-options http-proxy=$http_proxy --recv-keys 9C7DE460 \
    && apt-get update \
    && apt-get install --no-install-recommends --allow-unauthenticated -y \
    aptly \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs/ /

RUN ln -s usr/local/bin/docker-entrypoint.sh /

EXPOSE 8080
VOLUME ["/srv/aptly"]

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["aptly","api","serve","-no-lock"]
