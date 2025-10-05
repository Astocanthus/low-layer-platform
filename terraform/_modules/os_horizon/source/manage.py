#!/usr/bin/env python

import os
import sys
import pymysql

pymysql.version_info = (2, 2, 4, 'final', 0)
pymysql.install_as_MySQLdb()

from django.core.management import execute_from_command_line

if __name__ == "__main__":
  os.environ.setdefault("DJANGO_SETTINGS_MODULE", "openstack_dashboard.settings")
  execute_from_command_line(sys.argv)