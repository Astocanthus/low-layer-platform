#!/usr/bin/python

import json
import os
import requests
import sys

def main(args):
    base_url, token, domainId, filename = args[1], args[2], args[3], args[5]
    url = "%s/domains/%s/config" % (base_url, domainId)
    print("Connecting to url: %r" % url)

    headers = {
        'Content-Type': "application/json",
        'X-Auth-Token': token,
        'Cache-Control': "no-cache"
    }

    verify = os.getenv('OS_CACERT', True)
    response = requests.request("GET", url, headers=headers, verify=verify)

    if response.status_code == 404:
        print("domain config not found - put")
        action = "PUT"
    else:
        print("domain config found - patch")
        action = "PATCH"

    with open(filename, "rb") as f:
        data = {"config": json.load(f)}

    response = requests.request(action, url, data=json.dumps(data), headers=headers, verify=verify)
    print("Response code on action [%s]: %s" % (action, response.status_code))
    # Put and Patch can return 200 or 201. If it is not a 2XX code, error out.
    if (response.status_code // 100) != 2:
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 6:
        sys.exit(1)
    main(sys.argv)