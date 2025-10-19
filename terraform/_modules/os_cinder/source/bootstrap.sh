#!/bin/bash

set -ex
# export HOME=/tmp
#         openstack volume type show rbd1 || \
#         openstack volume type create \
#         --public \
#         --property volume_backend_name=rbd1 \
#         rbd1
openstack volume type list --long
openstack volume qos list

exit 0