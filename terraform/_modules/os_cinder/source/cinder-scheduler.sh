#!/bin/bash

set -ex
exec cinder-scheduler \
      --config-file /etc/cinder/cinder.conf