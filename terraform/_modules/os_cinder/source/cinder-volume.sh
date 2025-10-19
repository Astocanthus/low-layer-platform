#!/bin/bash

set -ex
exec cinder-volume \
      --config-file /etc/cinder/cinder.conf \
      --config-file /etc/cinder/conf/backends.conf \
      --config-file /tmp/pod-shared/internal_tenant.conf