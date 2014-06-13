#!/bin/bash

set -e

s3cmd put --acl-public chelfish.sh s3://bootstrap.ednit.net 
