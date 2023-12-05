#!/bin/bash
#
#

if ! type "yq" > /dev/null; then
  echo "Cannot find yq in the path, please install yq on the node first. ref: https://github.com/mikefarah/yq#install"
fi

BASEDIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

usage(){
  echo "Usage :   $0 command"
  echo "Example : $0 login https://192.168.13.146 Administrator:superuser"
  echo "Example : $0 managers"
  echo "Example : $0 bios '.Attributes.WorkloadProfile'"
  echo "Run : $0 login before using other commands"
  echo "Available commands : "
  echo "  login [bmc] [username:password]"
  echo "  system"
  echo "  systems"
  echo "  manager"
  echo "  managers"
  echo "  bios"
  echo "  eths"
  echo "  power"
  echo "  power on|off|restart"
  echo "  virtual-media"
  echo "  virtual-media insert http://192.168.58.15/iso/agent-130.iso"
  echo "  virtual-media eject"
  echo "  boot-once-from-cd"
}

if [ $# -lt 1 ]
then
  usage
  exit
fi

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit
fi

cmd=$1

if [ $# -gt 1 ]; then
  parameters=${@:2}
fi

login(){
  local bmc_info=($parameters)
  if [ "${#bmc_info[@]}" = 2 ]; then
    local bmc="${bmc_info[0]}"
    local username_password="${bmc_info[1]}"

    if [ $(curl -ku "$username_password" -s -o /dev/null -w ''%{http_code}'' "$bmc"/redfish/v1) -eq 200 ]; then
      echo "login succeed, will use $BASEDIR/.bmc.cfg next time."
      echo "bmc=$bmc" > "$BASEDIR"/.bmc.cfg
      echo "username_password=$username_password" >> "$BASEDIR"/.bmc.cfg
    else
      echo "login failed, please check."
      exit 1
    fi
  else
    echo "command invalid, please try login [bmc] [username:password]"
    exit 1
  fi

}

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

virtual-media(){
  local virtual_media_selected
  local manager=$(manager)
  local virtual_medias=$(curl -sku "${username_password}" "$manager"/"VirtualMedia" | jq -r '.Members[]."@odata.id"' )
  for virtual_media in $virtual_medias; do
    if [ $(curl -sku "${username_password}" "$bmc""$virtual_media" | jq '.MediaTypes[]' |grep -ciE 'CD|DVD') -gt 0 ]; then
      virtual_media_selected=$virtual_media
    fi
  done

  if [ -z "$parameters" ]; then
    curl -s --globoff -H "Content-Type: application/json" -H "Accept: application/json" \
      -k -X GET --user "${username_password}" \
      "$bmc""$virtual_media_selected"| jq
  else
    local virtual_media_ops=($parameters)
    local virtual_media_action="${virtual_media_ops[0]}"

    if [ "insert" = "$virtual_media_action" ]; then
      local iso_image="${virtual_media_ops[1]}"
      if [ -z "$iso_image" ]; then
        echo "Need to specify the ISO location."
      else
        curl --globoff -L -w "%{http_code} %{url_effective}\\n" -ku "${username_password}" \
          -H "Content-Type: application/json" -H "Accept: application/json" \
          -d "{\"Image\": \"${iso_image}\"}" \
          -X POST "$bmc""$virtual_media_selected"/Actions/VirtualMedia.InsertMedia
      fi
    fi

    if [ "eject" = "$virtual_media_action" ]; then
      curl --globoff -L -w "%{http_code} %{url_effective}\\n"  -ku "${username_password}" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        -d '{}'  -X POST "$bmc""$virtual_media_selected"/Actions/VirtualMedia.EjectMedia
    fi
  fi
}

boot-once-from-cd() {
    local system=$(system)
    curl --globoff  -L -w "%{http_code} %{url_effective}\\n"  -ku ${username_password}  \
    -H "Content-Type: application/json" -H "Accept: application/json" \
    -d '{"Boot":{ "BootSourceOverrideEnabled": "Once", "BootSourceOverrideTarget": "Cd" }}' \
    -X PATCH $system
}

if [ "login" = "$cmd" ]; then
  login
else
  if [ -f "$BASEDIR"/.bmc.cfg ]; then
    source "$BASEDIR"/.bmc.cfg
    $cmd
  else
    echo "Run login before using other commands."
    exit 1
  fi
fi
