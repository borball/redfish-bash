#!/bin/bash
#
#

if ! type "yq" > /dev/null; then
  echo "Cannot find yq in the path, please install yq on the node first. ref: https://github.com/mikefarah/yq#install"
fi

usage(){
  echo "Usage :   $0 bmc username:password command"
  echo "Example : $0 https://192.168.13.146 Administrator:superuser command"
  echo "Available commands : "
  echo "  system"
  echo "  systems"
  echo "  manager"
  echo "  managers"
  echo "  bios"
  echo "  eths"
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

systems(){
 local system=$(curl -sku "${username_password}" "$bmc"/redfish/v1/Systems | jq -r '.Members[0]."@odata.id"' )
 curl -sku "${username_password}" "$bmc""$system" |jq
}

manager(){
  local manager=$(curl -sku "${username_password}" "$bmc"/redfish/v1/Managers | jq -r '.Members[0]."@odata.id"' )
  echo "$bmc""$manager"
}

managers(){
  local manager=$(curl -sku "${username_password}" "$bmc"/redfish/v1/Managers | jq -r '.Members[0]."@odata.id"' )
  curl -sku "${username_password}" "$bmc""$manager" |jq
}

bios(){
  local system=$(system)
  curl -sku "${username_password}" "$system" |jq -r
}

eths(){
  local system=$(system)
  local ethernet_address=$(curl -sku "${username_password}" "$system" |jq -r '.EthernetInterfaces."@odata.id"')
  local ethernetInterfaces=$(curl -sku "${username_password}" "$bmc""$ethernet_address" |jq -r '.Members[]."@odata.id"')
  for ethernetInterface in $ethernetInterfaces; do
    curl -sku "${username_password}" "$bmc""$ethernetInterface" |jq '{Id,MACAddress,LinkStatus,Status}'
  done
}

if [ -n "$cmd" ]; then
  $cmd
fi
