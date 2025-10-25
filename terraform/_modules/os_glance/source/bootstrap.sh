#!/bin/bash

set -ex
export HOME=/tmp

cd /tmp/images

openstack image show "Cirros 0.6.2 64-bit" || \
  { curl --fail -sSL -O http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img; \
  openstack image create "Cirros 0.6.2 64-bit" \
  \
  --min-disk 1 \
  --disk-format qcow2 \
  --file cirros-0.6.2-x86_64-disk.img \
  --property os_distro=cirros \
  --container-format "bare" \
  --private; }

echo 'Not Enabled'