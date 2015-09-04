#!/bin/bash

packer build \
    -var 'region=us-west-1' \
    -var 'ami=ami-bf3ec1fb' \
    openvpn.json

packer build \
    -var 'region=us-west-2' \
    -var 'ami=ami-93868ea3' \
    openvpn.json

packer build \
    -var 'region=us-east-1' \
    -var 'ami=ami-478b262c' \
    openvpn.json
