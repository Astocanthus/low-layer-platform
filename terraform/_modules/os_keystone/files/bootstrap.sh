#!/bin/bash

set -ex

# admin needs the admin role for the default domain
openstack role add \
        --user="${OS_USERNAME}" \
        --domain="${OS_DEFAULT_DOMAIN}" \
        "admin"