#!/usr/bin/env python

import os
import re
import sys

import boto
from boto.s3.key import Key

HERE = (os.path.dirname(sys.argv[0]) if __name__ == '__main__'
        else os.path.dirname(__file__))

# For development/testing purposes, not for end users.
#
# Prerequisites:
#    pip install --upgrade boto
#
# Usage:
#
# (1) Save your config.json in the same directory where you have this file (or
#     adjust CONFIG_JSON_PATH so it points to your config.json.)
#
# (2) Run this from a directory that is sibling to your too-many-secrets
#     checkout (or adjust SECRETS_BASE_DIR so it points to your secrets
#     checkout.)
#
# (3) If your configurl is not in ~/.lantern-configurl.txt (unlikely!) adjust
#     CONFIGURL_PATH.
CONFIGURL_PATH = os.path.join(os.path.expanduser('~'),
                              '.lantern-configurl.txt')
CONFIG_JSON_PATH = os.path.join(HERE, 'config.json')
SECRETS_BASE_DIR = os.path.join(HERE, '..', 'too-many-secrets')


def read_aws_credential():
    aws_credential_path = os.path.join(SECRETS_BASE_DIR,
                                       'lantern_aws',
                                       'aws_credential')
    id_, key = None, None
    for line in file(aws_credential_path):
        line = line.strip()
        m = re.match(r"AWSAccessKeyId=(.*)", line)
        if m:
            id_ = m.groups()[0]
        m = re.match("AWSSecretKey=(.*)", line)
        if m:
            key = m.groups()[0]
    assert id_ and key
    return {'aws_access_key_id': id_,
            'aws_secret_access_key': key}

def run():
    conn = boto.connect_s3(**read_aws_credential())
    bucket = conn.get_bucket("lantern-config")
    key = Key(bucket)
    configurl = file(CONFIGURL_PATH).read().strip()
    key.name = "%s/config.json" % configurl
    key.set_contents_from_filename(CONFIG_JSON_PATH, replace=True)
    key.set_acl('public-read')


if __name__ == '__main__':
    run()
