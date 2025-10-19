#!/bin/bash

set -ex
export HOME=/tmp

cat <<EOF > /etc/ceph/ceph.client.admin.keyring
[client.admin]
    key = $(cat /tmp/client-keyring)
EOF

exit 0