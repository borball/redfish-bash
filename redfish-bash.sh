#!/bin/bash
#
#

if ! type "yq" > /dev/null; then
  echo "Cannot find yq in the path, please install yq on the node first. ref: https://github.com/mikefarah/yq#install"
fi

usage(){
  echo "Usage : $0 bmc username:password command"
  echo "Example : $0 https://192.168.13.146 Administrator:superuser command"
  echo "available commands:"
  echo "  system"
  echo "  manager"
  echo "  bios"
}

if [ $# -lt 3 ]
then
  usage
  exit
fi

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit
fi

bmc=$1
username_password=$2
cmd=$3

system(){
 local system=$(curl -sku "${username_password}" "$bmc"/redfish/v1/Systems | jq -r '.Members[0]."@odata.id"' )
  echo "$bmc""$system"
}

manager(){
  local manager=$(curl -sku "${username_password}" "$bmc"/redfish/v1/Managers | jq -r '.Members[0]."@odata.id"' )
  echo "$bmc""$manager"
}

bios(){
  local system=$(system)
  curl -sku "${username_password}" "$system" |jq -r
}

if [ -n "$cmd" ]; then
  $cmd
fi
