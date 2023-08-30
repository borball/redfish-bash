#!/bin/bash
#
#

if ! type "yq" > /dev/null; then
  echo "Cannot find yq in the path, please install yq on the node first. ref: https://github.com/mikefarah/yq#install"
fi

usage(){
  echo "Usage :   $0 bmc username:password command [json_path]"
  echo "Example : $0 https://192.168.13.146 Administrator:superuser managers"
  echo "Example : $0 https://192.168.13.146 Administrator:superuser bios '.Attributes.WorkloadProfile'"
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
if [ $# -gt 3 ]; then
  parameters=${@:4}
fi

system(){
 local system=$(curl -sku "${username_password}" "$bmc"/redfish/v1/Systems | jq -r '.Members[0]."@odata.id"' )
  echo "$bmc""$system"
}

systems(){
  local system=$(system)
 
  if [ -n "$parameters" ]; then
    curl -sku "${username_password}" "$system" |jq -r "$parameters"
  else
    curl -sku "${username_password}" "$system" |jq
  fi
 
}

manager(){
  local manager=$(curl -sku "${username_password}" "$bmc"/redfish/v1/Managers | jq -r '.Members[0]."@odata.id"' )
  echo "$bmc""$manager"
}

managers(){
  local manager=$(manager)

  if [ -n "$parameters" ]; then
    curl -sku "${username_password}" "$manager" |jq -r "$parameters"
  else
    curl -sku "${username_password}" "$manager" |jq
  fi
}

bios(){
  local system=$(system)
  local bios=$(curl -sku "${username_password}" "$system"|jq -r '.Bios."@odata.id"')

  if [ -n "$parameters" ]; then
    curl -sku "${username_password}" "$bmc""$bios" |jq -r "$parameters"
  else
    curl -sku "${username_password}" "$bmc""$bios" |jq
  fi
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
