#!/bin/bash

set -ex
export HOME=/tmp

cat <<EOF > /etc/ceph/ceph.client.${RBD_USER}.keyring
[client.${RBD_USER}]
    key = $(cat /tmp/client-keyring)
EOF

exit 0