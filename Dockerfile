# build Unbound
FROM alpine:3.21 AS unbound

RUN apk add --no-cache \
    make \
    clang \
    bison \
    flex \
    openssl-dev \
    expat-dev \
    libevent-dev \
    nghttp2-dev

RUN mkdir -p /working/
WORKDIR /working/

ARG unbound_ver=1.22.0

RUN <<EOF
wget -O unbound.tar.gz https://nlnetlabs.nl/downloads/unbound/unbound-${unbound_ver}.tar.gz
mkdir -p source/
tar -xzf unbound.tar.gz --strip-components 1 -C ./source/
EOF

WORKDIR /working/source/

RUN ./configure \
    --prefix=/usr/local/ \
    --with-username=unbound \
    --with-ssl \
    --with-pthreads \
    --with-libevent \
    --with-libnghttp2

RUN <<EOF
mkdir -p /install/unbound/
make -j $(nproc)
make install DESTDIR=/install/unbound/
EOF

# the finally runtime
FROM alpine:3.21 AS runtime

RUN apk add --no-cache \
    openssl \
    expat \
    libevent \
    nghttp2

RUN <<EOF
addgroup -S unbound
adduser -S -G unbound unbound
EOF

COPY --from=unbound /install/unbound/ /

RUN <<EOF
mkdir -p /etc/unbound/
cp /usr/local/etc/unbound/unbound.conf /etc/unbound/unbound.conf
EOF

COPY ./unbound.sh /usr/local/bin/

WORKDIR /

ENTRYPOINT [ "/usr/local/bin/unbound.sh" ]
