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

RUN git clone --depth 1 -b openssl-3.1.7+quic --recurse-submodules -j $(nproc) \
    https://github.com/quictls/openssl source/

WORKDIR /working/source/

RUN ./config \
    --prefix=/install/openssl/ \
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
make install
EOF

# build ngtcp2 with openssl+quic
FROM alpine:3.21 AS ngtcp2

RUN apk add --no-cache \
    git \
    make \
    clang \
    pkgconf \
    autoconf \
    automake \
    libtool

RUN mkdir -p /working/
WORKDIR /working/

RUN git clone --depth 1 -b v1.11.0 --recurse-submodules -j $(nproc) \
    https://github.com/ngtcp2/ngtcp2 source/

WORKDIR /working/source/

COPY --from=openssl /install/openssl/ /install/openssl/

RUN <<EOF
autoreconf -i
./configure \
    --prefix=/install/ngtcp2/ \
    PKG_CONFIG_PATH=/install/openssl/lib/pkgconfig \
    LDFLAGS="-Wl,-rpath,/install/openssl/lib"
EOF

RUN <<EOF
make -j $(nproc)
make install
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

COPY --from=openssl /install/openssl/ /install/openssl/
COPY --from=ngtcp2 /install/ngtcp2/ /install/ngtcp2/

RUN ./configure \
    --prefix=/usr/local/ \
    --with-username=unbound \
    --with-ssl=/install/openssl/ \
    --with-pthreads \
    --with-libevent \
    --with-libnghttp2 \
    --with-libngtcp2=/install/ngtcp2/ \
    LDFLAGS="-Wl,-rpath -Wl,/install/ngtcp2/lib/"

RUN <<EOF
mkdir -p /install/unbound/
make -j $(nproc)
make install DESTDIR=/install/unbound/
EOF

# the finally runtime
FROM alpine:3.21 AS runtime

RUN apk add --no-cache \
    expat \
    libevent \
    nghttp2

RUN <<EOF
addgroup -S unbound
adduser -S -G unbound unbound
EOF

COPY --from=openssl /install/openssl/ /install/openssl/
COPY --from=ngtcp2 /install/ngtcp2/ /install/ngtcp2/
COPY --from=unbound /install/unbound/ /

RUN <<EOF
mkdir -p /etc/unbound/
cp /usr/local/etc/unbound/unbound.conf /etc/unbound/unbound.conf
EOF

COPY ./unbound.sh /usr/local/bin/

WORKDIR /

ENTRYPOINT [ "/usr/local/bin/unbound.sh" ]
