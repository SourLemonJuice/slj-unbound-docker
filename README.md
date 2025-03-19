# SourLemonJuice Unbound docker image

This is a docker image of **Unbound** DNS server for `dns.sourlemonjuice.net`

> Warning: Unusable now

## Build flow

This image based on Alpine Linux base image, it's a tiny and simple choices.\
It also won't build OpenSSL and other dependencies by itself, download from the distribution repository is more less prone to make mistakes.

Then build the Unbound self and copy the init script, that's all. The Unbound build prefix is `/usr/local/`.

## QUIC support

I was to do that, but now it is trying in the `main+quic` branch.

> Why can't it build... qwq

## Usage

The docker compose example like this, nothing special:

```yaml
name: unbound

services:
  unbound:
    image: sourlemonjuice/slj-unbound:latest
    restart: always
    ports:
     - 53:53/tcp
     - 53:53/udp
    volumes:
      - ./unbound.conf:/etc/unbound/unbound.conf:ro
```

## DNSSEC anchor

When init script process, anchor will be updated, you can set to this file to use it:

```text
auto-trust-anchor-file: "/usr/local/etc/unbound/root.key"
```

## Tags

The tags named by: `<unbound version>-<revision>[+quic]`\
Published on Docker Hub([sourlemonjuice/slj-unbound](https://hub.docker.com/r/sourlemonjuice/slj-unbound)).

But don't expect the QUIC version yet.
