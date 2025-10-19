#!/bin/bash

set -ex

exec kubectl delete secret \
  --namespace ${NAMESPACE} \
  --ignore-not-found=true \
  ${RBD_POOL_SECRET}