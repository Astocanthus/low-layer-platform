#!/bin/bash

set -ex

COMMAND="${@:-start}"

function start () {
    for KEYSTONE_WSGI_SCRIPT in keystone-wsgi-public; do
    cp -a $(type -p ${KEYSTONE_WSGI_SCRIPT}) /var/www/cgi-bin/keystone/
    done
    a2enmod headers
    a2enmod rewrite
    a2enmod ssl

    if [ -f /etc/apache2/envvars ]; then
        # Loading Apache2 ENV variables
        source /etc/apache2/envvars
    fi

    if [ -f /var/run/apache2/apache2.pid ]; then
        # Remove the stale pid for debian/ubuntu images
        rm -f /var/run/apache2/apache2.pid
    fi

    # Start Apache2
    exec apache2 -DFOREGROUND
}

function stop () {
    if [ -f /etc/apache2/envvars ]; then
        # Loading Apache2 ENV variables
        source /etc/apache2/envvars
    fi
    apache2 -k graceful-stop
}

$COMMAND