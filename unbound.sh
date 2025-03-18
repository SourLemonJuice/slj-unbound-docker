#!/bin/sh

# should I?
# set -e

echo "unbound.sh: Starting create DNSSEC anchor"
unbound-anchor -v -a "/usr/local/etc/unbound/root.key"

echo "unbound.sh: Starting unbound daemon process"
exec unbound -d -c "/etc/unbound/unbound.conf" "$@"
