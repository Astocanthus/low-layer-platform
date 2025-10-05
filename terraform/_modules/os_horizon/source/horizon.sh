#!/bin/bash

set -ex
COMMAND="${@:-start}"

function start () {
  SITE_PACKAGES_ROOT=$(python -c "from sysconfig import get_path; print(get_path('platlib'))")
  rm -f ${SITE_PACKAGES_ROOT}/openstack_dashboard/local/local_settings.py
  ln -s /etc/openstack-dashboard/local_settings ${SITE_PACKAGES_ROOT}/openstack_dashboard/local/local_settings.py
  ln -s  ${SITE_PACKAGES_ROOT}/openstack_dashboard/conf/default_policies  /etc/openstack-dashboard/default_policies
  # wsgi/horizon-http needs open files here, including secret_key_store
  chown -R horizon ${SITE_PACKAGES_ROOT}/openstack_dashboard/local/
  a2enmod headers
  a2enmod rewrite
  a2enmod ssl
  a2dismod status

  if [ -f /etc/apache2/envvars ]; then
    # Loading Apache2 ENV variables
    source /etc/apache2/envvars
    # The directory below has to be created due to the fact that
    # libapache2-mod-wsgi-py3 doesn't create it in contrary by libapache2-mod-wsgi
    if [ ! -d ${APACHE_RUN_DIR} ]; then
      mkdir -p ${APACHE_RUN_DIR}
    fi
  fi
  rm -rf /var/run/apache2/*
  APACHE_DIR="apache2"

  # Add extra panels if available
  PANEL_DIR="${SITE_PACKAGES_ROOT}/heat_dashboard/enabled"
  if [ -d ${PANEL_DIR} ];then
    for panel in `ls -1 ${PANEL_DIR}/_[1-9]*.py`
    do
      ln -s ${panel} ${SITE_PACKAGES_ROOT}/openstack_dashboard/local/enabled/$(basename ${panel})
    done
  fi
  unset PANEL_DIR
  PANEL_DIR="${SITE_PACKAGES_ROOT}/heat_dashboard/local/enabled"
  if [ -d ${PANEL_DIR} ];then
    for panel in `ls -1 ${PANEL_DIR}/_[1-9]*.py`
    do
      ln -s ${panel} ${SITE_PACKAGES_ROOT}/openstack_dashboard/local/enabled/$(basename ${panel})
    done
  fi
  unset PANEL_DIR
  PANEL_DIR="${SITE_PACKAGES_ROOT}/neutron_taas_dashboard/enabled"
  if [ -d ${PANEL_DIR} ];then
    for panel in `ls -1 ${PANEL_DIR}/_[1-9]*.py`
    do
      ln -s ${panel} ${SITE_PACKAGES_ROOT}/openstack_dashboard/local/enabled/$(basename ${panel})
    done
  fi
  unset PANEL_DIR
  PANEL_DIR="${SITE_PACKAGES_ROOT}/neutron_taas_dashboard/local/enabled"
  if [ -d ${PANEL_DIR} ];then
    for panel in `ls -1 ${PANEL_DIR}/_[1-9]*.py`
    do
      ln -s ${panel} ${SITE_PACKAGES_ROOT}/openstack_dashboard/local/enabled/$(basename ${panel})
    done
  fi
  unset PANEL_DIR

  # If the image has support for it, compile the translations
  if type -p gettext >/dev/null 2>/dev/null; then
    cd ${SITE_PACKAGES_ROOT}/openstack_dashboard; /tmp/manage.py compilemessages
    # if there are extra panels and the image has support for it, compile the translations
    PANEL_DIR="${SITE_PACKAGES_ROOT}/heat_dashboard"
    if [ -d ${PANEL_DIR} ]; then
      cd ${PANEL_DIR}; /tmp/manage.py compilemessages
    fi
    PANEL_DIR="${SITE_PACKAGES_ROOT}/neutron_taas_dashboard"
    if [ -d ${PANEL_DIR} ]; then
      cd ${PANEL_DIR}; /tmp/manage.py compilemessages
    fi
    unset PANEL_DIR
  fi

  # Copy custom logo images
  if [[ -f /tmp/favicon.svg ]]; then
    cp /tmp/favicon.svg ${SITE_PACKAGES_ROOT}/openstack_dashboard/static/dashboard/img/favicon.svg
  fi
  if [[ -f /tmp/logo.svg ]]; then
    cp /tmp/logo.svg ${SITE_PACKAGES_ROOT}/openstack_dashboard/static/dashboard/img/logo.svg
  fi
  if [[ -f /tmp/logo-splash.svg ]]; then
    cp /tmp/logo-splash.svg ${SITE_PACKAGES_ROOT}/openstack_dashboard/static/dashboard/img/logo-splash.svg
  fi

  # Compress Horizon's assets.
  /tmp/manage.py collectstatic --noinput
  /tmp/manage.py compress --force
  rm -rf /tmp/_tmp_.secret_key_store.lock /tmp/.secret_key_store
  chmod +x ${SITE_PACKAGES_ROOT}/django/core/wsgi.py
  exec apache2 -DFOREGROUND
}

function stop () {
  apache2 -k graceful-stop
}

$COMMAND