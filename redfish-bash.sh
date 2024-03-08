#!/bin/bash
#
#

if ! type "yq" > /dev/null; then
  echo "Cannot find yq in the path, please install yq on the node first. ref: https://github.com/mikefarah/yq#install"
fi

BASEDIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ALL_SERVERS_CFG="$BASEDIR/.bmc-all.yaml"
CURRENT_SERVERS_CFG="$BASEDIR/.bmc-current.yaml"

usage(){
  echo "Usage :   $0 command <parameters>"
  echo "Example : $0 login https://192.168.13.146 Administrator:superuser"
  echo "Example : $0 login https://192.168.13.146 Administrator:superuser [kvm_uuid]"
  echo "Example : $0 managers"
  echo "Example : $0 bios '.Attributes.WorkloadProfile'"
  echo "Run : $0 login before using other commands"
  echo "Available commands : "
  echo "  -------------------------------------------"
  echo "  #login BMC"
  echo "  login [bmc] [username:password]"
  echo "  login [bmc] [username:password] [kvm_uuid]"
  echo "  -------------------------------------------"
  echo "  #bmc server context"
  echo "  #all servers:"
  echo "  servers"
  echo "  #current server"
  echo "  server"
  echo "  #use server N"
  echo "  server N"
  echo "  -------------------------------------------"
  echo "  #resource management"
  echo "  system"
  echo "  systems"
  echo "  manager"
  echo "  managers"
  echo "  #BMC reset"
  echo "  reset"
  echo "  bios"
  echo "  bios-attr k v"
  echo "  eths"
  echo "  power"
  echo "  power on|off|restart"
  echo "  virtual-media"
  echo "  virtual-media insert http://192.168.58.15/iso/agent-130.iso"
  echo "  virtual-media eject"
  echo "  boot-once-from-cd"
  echo "  secure-boot"
  echo "  secure-boot true|false"
  echo "  storage"

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

_save_cfg(){
  local total=$(yq ".|length" "$ALL_SERVERS_CFG")
  echo "- index: $total" >> "$ALL_SERVERS_CFG"
  echo "  bmc: $1" >> "$ALL_SERVERS_CFG"
  echo "  userPass: $2" >> "$ALL_SERVERS_CFG"

  echo "index: $total" > "$CURRENT_SERVERS_CFG"
  echo "bmc: $1" >> "$CURRENT_SERVERS_CFG"
  echo "userPass: $2" >> "$CURRENT_SERVERS_CFG"

  yq "$CURRENT_SERVERS_CFG"
  export bmc=$(yq ".bmc" "$CURRENT_SERVERS_CFG")
  export username_password=$(yq ".userPass" "$CURRENT_SERVERS_CFG")
}

login(){
  local bmc_info=($parameters)

  if [ "${#bmc_info[@]}" -gt 1 ]; then
    local bmc="${bmc_info[0]}"
    local username_password="${bmc_info[1]}"

    local redfish_url="$bmc"/redfish/v1
    if [ "${#bmc_info[@]}" = 3 ]; then
      uuid="${bmc_info[2]}"
      redfish_url="$redfish_url/Systems/$uuid"
    fi

    if [ $(curl -ku "$username_password" -s -o /dev/null -w ''%{http_code}'' "$redfish_url") -eq 200 ]; then
      #login succeed
      echo "login successful, will use this server for the following commands."
      _save_cfg "$bmc" "$username_password"
    else
      echo "login failed, please check."
      exit 1
    fi

  else
    echo "command invalid, please try redfish-bash.sh login [bmc] [username:password] or: redfish-bash.sh login [bmc] [username:password] [kvm_uuid]"
    exit 1
  fi

}

#list all bmc servers saved in the config
servers(){
  echo
  echo "All servers in the list:"
  yq '.[]|(.index + "   "  + .bmc)' "$ALL_SERVERS_CFG"

  echo "use command 'server' to check the current server"
  echo "use command 'server N' to switch the servers"
}

#choose one of the bmc servers from the server list
server(){
  if [ -n "$parameters" ]; then
    re='^[0-9]+$'
    if ! [[ $parameters =~ $re ]] ; then
      echo "error: $parameters not a number" >&2; exit 1
    fi
    if [[ $(yq ".[$parameters]" "$ALL_SERVERS_CFG") != "null" ]]; then
      echo "following server will be used:"
      yq ".[$parameters]" "$ALL_SERVERS_CFG"
      yq ".[$parameters]" "$ALL_SERVERS_CFG" > "$CURRENT_SERVERS_CFG"
    else
      echo "server with index $parameters not found"
    fi
  else
    echo "following server is being used:"
    yq "$CURRENT_SERVERS_CFG"
  fi

  export bmc=$(yq ".bmc" "$CURRENT_SERVERS_CFG")
  export username_password=$(yq ".userPass" "$CURRENT_SERVERS_CFG")
}

system(){
  if [ -z "$uuid" ]; then
    local system=$(curl -sku "${username_password}" "$bmc"/redfish/v1/Systems | jq -r '.Members[0]."@odata.id"' )
  else
    local system=/redfish/v1/Systems/"$uuid"
  fi

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
  if [ -z "$uuid" ]; then
    local manager=$(curl -sku "${username_password}" "$bmc"/redfish/v1/Managers | jq -r '.Members[0]."@odata.id"' )
  else
    local manager=/redfish/v1/Managers/"$uuid"
  fi

  echo "$bmc""$manager"
}

reset(){
  local manager=$(manager)
  local reset=$(curl -sku "${username_password}" "$manager" |jq -r ".Actions.\"#Manager.Reset\".target")
  local reset_type="ForceRestart"
  curl --globoff  -L -w "%{http_code} %{url_effective}\\n" -ku "${username_password}" \
  -H "Content-Type: application/json" -H "Accept: application/json" \
  -d "{\"ResetType\": \"${reset_type}\"}" \
  -X POST "$bmc""$reset"
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

bios-attr(){
  if [ -n "$parameters" ]; then
    local system=$(system)
    local bios=$(curl -sku "${username_password}" "$system"|jq -r '.Bios."@odata.id"')
    local settings=$(curl -sku "${username_password}" "$bmc""$bios" |jq -r ".\"@Redfish.Settings\".SettingsObject.\"@odata.id\"")
    local k_v=($parameters)
    local key=${k_v[0]}
    local value=${k_v[1]}

    curl --globoff  -L -w "%{http_code} %{url_effective}\\n"  -ku ${username_password}  \
    -H "Content-Type: application/json" -H "Accept: application/json" \
    -d "{\"Attributes\":{\"$key\": \"$value\"}}" \
    -X PATCH "$bmc""$settings"

  else
    echo "Usage: $0 key value"
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

secure-boot(){
  local system=$(system)
  local secure_boot="$bmc"$(curl -sku "${username_password}" "$system" |jq -r '.SecureBoot."@odata.id"')
  local enabled=$(curl -sku "${username_password}" "$secure_boot" |jq -r ".SecureBootEnable")

  if [ -z "$parameters" ]; then
    echo "$enabled"
  else
    if [ $parameters = $enabled ]; then
      echo "secure boot is already $parameters, no need to change."
    else
      if [ "true" = "$parameters" ] || [ "false" = "$parameters" ]; then
        local body="{\"SecureBootEnable\":$parameters}"
        curl -sku "${username_password}" -X PATCH -H "Content-Type: application/json" -d "$body" "$secure_boot"
        echo "secure boot has been set as $parameters, you may need to reboot the node to take effect."
      else
        echo "$parameters is not supported, it should be true or false"
      fi
    fi
  fi
}

storage(){
  local system=$(system)
  local storage="$bmc"$(curl -sku "${username_password}" "$system" |jq -r '.Storage."@odata.id"')
  if [ -n "$parameters" ]; then
    curl -sku "${username_password}" "$storage"/"$parameters" |jq
  else
    curl -sku "${username_password}" "$storage" |jq
  fi
}

if [ "login" = "$cmd" ]; then
  login
elif [ "server" = "$cmd" ]; then
  server
else
  server
  $cmd
fi
