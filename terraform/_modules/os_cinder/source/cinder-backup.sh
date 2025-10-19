#!/bin/bash

set -ex
exec cinder-backup \
      --config-file /etc/cinder/cinder.conf