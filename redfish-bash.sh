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
  echo "  power"
  echo "  power on|off|restart"
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

power() {
  local system=$(system)

  if [ -z "$parameters" ]; then
    curl -sku "${username_password}" "$system" |jq -r ".PowerState"
  else
    local reset_type
    if [ "off" = "$parameters" ]; then
      reset_type="ForceOff"
    fi
    if [ "on" = "$parameters" ]; then
      reset_type="On"
    fi
    if [ "restart" = "$parameters" ]; then
      reset_type="ForceRestart"
    fi

    if [ -n "$reset_type" ]; then
      curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku "${username_password}" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        -d "{\"ResetType\": \"${reset_type}\"}" \
        -X POST "$system"/Actions/ComputerSystem.Reset
    else
      echo "$parameters is not valid command."
    fi
  fi
}

if [ -n "$cmd" ]; then
  $cmd
fi
