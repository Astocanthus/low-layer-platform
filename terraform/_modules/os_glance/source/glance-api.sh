#!/bin/bash

set -ex
COMMAND="${@:-start}"

function start () {
  exec uwsgi --ini /etc/glance/glance-api-uwsgi.ini
}

function stop () {
  kill -TERM 1
}

$COMMAND