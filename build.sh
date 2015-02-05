#!/bin/bash

packer build \
    -var 'region=us-west-1' \
    -var 'ami=ami-5c120b19' \
    openvpn.json

packer build \
    -var 'region=us-west-2' \
    -var 'ami=ami-29ebb519' \
    openvpn.json

packer build \
    -var 'region=us-east-1' \
    -var 'ami=ami-9a562df2' \
    openvpn.json
