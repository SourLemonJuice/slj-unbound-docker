# build openssl with QUIC
FROM alpine:3.21 AS openssl

RUN apk add --no-cache \
    linux-headers \
    git \
    make \
    clang \
    perl

RUN mkdir -p /working/
WORKDIR /working/

RUN git clone --depth 1 -b OpenSSL_1_1_1o+quic --recurse-submodules -j $(nproc) \
    https://github.com/quictls/openssl \
    source/

WORKDIR /working/source/

RUN ./config \
    --prefix=/usr/local/ \
    enable-tls1_3 \
    no-shared \
    threads \
    no-weak-ssl-ciphers \
    no-ssl3 \
    -DOPENSSL_NO_HEARTBEATS \
    -fstack-protector-strong

RUN <<EOF
mkdir -p /install/openssl/
make depend -j $(nproc)
make -j $(nproc)
make install DESTDIR=/install/openssl/
EOF

# build Unbound
FROM alpine:3.21 AS unbound

RUN apk add --no-cache \
    make \
    clang \
    bison \
    flex \
    expat-dev \
    libevent-dev \
    nghttp2-dev \
    ngtcp2-dev

COPY --from=openssl /install/openssl/ /

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
    --with-pthreads \
    --with-libevent \
    --with-libnghttp2

RUN <<EOF
mkdir -p /install/unbound/
make -j $(nproc)
make install DESTDIR=/install/unbound/
EOF

# the finally runtime
FROM alpine:3.21

RUN apk add --no-cache \
    expat \
    libevent \
    nghttp2 \
    ngtcp2

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

ENTRYPOINT [ "/usr/local/bin/unbound.sh" ]
