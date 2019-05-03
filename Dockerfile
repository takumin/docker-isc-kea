# vim: set ft=dockerfile :

#
# Build Container
#

FROM alpine:edge AS build
LABEL maintainer "Takumi Takahashi <takumiiinn@gmail.com>"

RUN echo "Build Config Starting" \
 && apk --update add \
    wget \
    ca-certificates \
 && echo "Build Config Complete!"

# Install Dockerize
ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# Copy Entrypoint Script
COPY ./injection/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

# Copy Config Template
RUN mkdir /usr/local/etc
COPY ./injection/kea-ctrl-agent.conf.tmpl /usr/local/etc/kea-ctrl-agent.conf.tmpl
COPY ./injection/kea-dhcp4.conf.tmpl /usr/local/etc/kea-dhcp4.conf.tmpl
COPY ./injection/kea-dhcp6.conf.tmpl /usr/local/etc/kea-dhcp6.conf.tmpl

#
# Deploy Api Container
#

FROM alpine:edge AS api
LABEL maintainer "Takumi Takahashi <takumiiinn@gmail.com>"

COPY --from=build /usr/local /usr/local

RUN echo "Deploy Config Starting" \
 && echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
 && apk --no-cache --update add \
    runit \
    kea-ctrl-agent@testing \
    kea-hook-runscript@testing \
 && echo "Deploy Config Complete!"

VOLUME ["/etc/kea", "/var/lib/kea"]
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["api"]
EXPOSE 8080/tcp

#
# Deploy DHCPv4 Container
#

FROM alpine:edge AS dhcp4
LABEL maintainer "Takumi Takahashi <takumiiinn@gmail.com>"

COPY --from=build /usr/local /usr/local

RUN echo "Deploy Config Starting" \
 && echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
 && apk --no-cache --update add \
    runit \
    kea-dhcp4@testing \
    kea-hook-runscript@testing \
 && echo "Deploy Config Complete!"

VOLUME ["/etc/kea", "/var/lib/kea"]
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["dhcp4"]

#
# Deploy DHCPv6 Container
#

FROM alpine:edge AS dhcp6
LABEL maintainer "Takumi Takahashi <takumiiinn@gmail.com>"

COPY --from=build /usr/local /usr/local

RUN echo "Deploy Config Starting" \
 && echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
 && apk --no-cache --update add \
    runit \
    kea-dhcp6@testing \
    kea-hook-runscript@testing \
 && echo "Deploy Config Complete!"

VOLUME ["/etc/kea", "/var/lib/kea"]
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["dhcp6"]
