#!/bin/bash

set -ex

COMMAND="${@:-start}"

function start () {
    # Si .Values.manifests.certificates est true
    for WSGI_SCRIPT in cinder-wsgi; do
        cp -a $(type -p ${WSGI_SCRIPT}) /var/www/cgi-bin/cinder/
    done
    
    if [ -f /etc/apache2/envvars ]; then
        # Loading Apache2 ENV variables
        source /etc/apache2/envvars
        mkdir -p ${APACHE_RUN_DIR}
    fi
    
    # Modules Apache2 à activer (selon .Values.conf.software.apache2.a2enmod)
    a2enmod headers
    a2enmod rewrite
    a2enmod ssl
    
    if [ -f /var/run/apache2/apache2.pid ]; then
        # Remove the stale pid for debian/ubuntu images
        rm -f /var/run/apache2/apache2.pid
    fi
    
    # Starts Apache2
    exec apache2 -DFOREGROUND
    
    # Si .Values.manifests.certificates est false, alors :
    # exec uwsgi --ini /etc/cinder/cinder-api-uwsgi.ini
}

function stop () {
    # Si .Values.manifests.certificates est true
    if [ -f /etc/apache2/envvars ]; then
        # Loading Apache2 ENV variables
        source /etc/apache2/envvars
        mkdir -p ${APACHE_RUN_DIR}
    fi
    
    apache2 -k graceful-stop
    
    # Si .Values.manifests.certificates est false, alors :
    # kill -TERM 1
}

$COMMAND