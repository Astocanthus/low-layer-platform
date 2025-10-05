#!/bin/bash

set -ex

SITE_PACKAGES_ROOT=$(python -c "from sysconfig import get_path; print(get_path('platlib'))")
rm -f ${SITE_PACKAGES_ROOT}/openstack_dashboard/local/local_settings.py
ln -s /etc/openstack-dashboard/local_settings ${SITE_PACKAGES_ROOT}/openstack_dashboard/local/local_settings.py

exec /tmp/manage.py migrate --noinput