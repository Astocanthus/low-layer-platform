#!/bin/bash

set -ex

COMMAND="${@:-start}"

function start () {
    # Copy the placement WSGI script
    for WSGI_SCRIPT in placement-api; do
        cp -a $(type -p ${WSGI_SCRIPT}) /var/www/cgi-bin/placement/
    done
    
    if [ -f /etc/apache2/envvars ]; then
        # Loading Apache2 ENV variables
        source /etc/apache2/envvars
        mkdir -p ${APACHE_RUN_DIR}
    fi
    
    # Apache2 modules to enable
    a2enmod headers
    a2enmod rewrite
    a2enmod ssl
    
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
        mkdir -p ${APACHE_RUN_DIR}
    fi
    
    apache2 -k graceful-stop
}

$COMMAND