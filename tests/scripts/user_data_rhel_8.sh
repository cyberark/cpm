#!/bin/bash
sudo yum update -y
sudo yum install -y git python2 python2-devel gcc krb5-devel
curl -s https://bootstrap.pypa.io/get-pip.py | sudo python2
sudo pip install ansible pywinrm boto3 botocore kerberos requests-kerberos --ignore-installed