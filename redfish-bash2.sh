#!/bin/bash
#
#
umask 0066

if ! type "yq" > /dev/null; then
  echo "Cannot find yq in the path, please install yq on the node first. ref: https://github.com/mikefarah/yq#install"
fi

if ! type "jq" > /dev/null; then
  echo "Cannot find jq in the path, please install jq(1.7+) on the node first. ref: https://github.com/jqlang/jq?tab=readme-ov-file#installation"
fi

BASEDIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ALL_SERVERS_CFG="$BASEDIR/.bmc-all.yaml"
CURRENT_SERVERS_CFG="$BASEDIR/.bmc-current.yaml"
touch "$ALL_SERVERS_CFG"

usage(){
  echo "Usage :   $0 command <parameters>"
  echo "Available commands: "
  echo "  -------------------------------------------"
  echo "  #login BMC"
  echo "  login <bmc> [kvm_uuid]"
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
  echo "  root"
  echo "  system"
  echo "  system <jsonpath>"
  echo "  manager"
  echo "  manager <jsonpath>"
  echo "  #BMC reset"
  echo "  bmc-reboot"
  echo "  bios"
  echo "  #read attributes"
  echo "  bios <jsonpath>"
  echo "  #modify attribute"
  echo "  bios <attribute=value>"
  echo "  eths"
  echo "  power"
  echo "  power on|off|restart|nmi"
  echo "  virtual-media"
  echo "  virtual-media insert <url>"
  echo "  virtual-media eject"
  echo "  boot-once-from-cd"
  echo "  secure-boot"
  echo "  secure-boot true|false"
  echo "  storage"
  echo "  storage <ID>"
  echo
  echo "Examples: "
  echo "  $0 login https://192.168.13.146 admin password"
  echo "  $0 servers"
  echo "  $0 server"
  echo "  $0 server 0"
  echo "  $0 root"
  echo "  $0 system"
  echo "  $0 system Manufacturer,Model"
  echo "  $0 manager"
  echo "  $0 manager FirmwareVersion,PowerState,ManagerType"
  echo "  $0 bios"
  echo "  $0 bios Attributes.WorkloadProfile"
  echo "  $0 bios WorkloadProfile=vRAN"
  echo "  $0 eths"
  echo "  $0 power"
  echo "  $0 power on|off|restart|nmi"
  echo "  $0 virtual-media"
  echo "  $0 virtual-media insert http://192.168.58.15/iso/agent-130.iso"
  echo "  $0 virtual-media eject"
  echo "  $0 boot-once-from-cd"
  echo "  $0 secure-boot"
  echo "  $0 secure-boot true|false"
  echo "  $0 storage"
  echo "  $0 storage DA000000"
  echo "  $0 get"
  echo "  $0 get /redfish/v1/TelemetryService"
  echo "Run : $0 login before using other commands for the first time."
}

help(){
  usage
}

help(){
  usage
}

_log(){
  if [[ "true" == "$DEBUG" ]]; then
    echo "$@"
  fi
}

_save_cfg(){
  export bmc=$1
  index=$(yq ".[]|select(.bmc == \"$bmc\")|.index" "$ALL_SERVERS_CFG")
  if [ -z "$index" ]; then
    index=$(yq ".|length" "$ALL_SERVERS_CFG")
    yq -i ". += [{\"index\": ${index}, \"bmc\": \"$1\", \"auth_token\": \"$2\", \"location\": \"$3\"}]" "$ALL_SERVERS_CFG"
  else
    #delete the element which index is $index
    yq -i "del(.[]|select(.index == ${index}))" "$ALL_SERVERS_CFG"
    yq -i ". += [{\"index\": ${index}, \"bmc\": \"$1\", \"auth_token\": \"$2\", \"location\": \"$3\"}]" "$ALL_SERVERS_CFG"
  fi

  #order by index
  yq -i ". |= sort_by(.index)" "$ALL_SERVERS_CFG"

  yq ".[]|select(.index == ${index})" "$ALL_SERVERS_CFG" > "$CURRENT_SERVERS_CFG"
  cat "$CURRENT_SERVERS_CFG"
}

_pick(){
  echo $1 | cut -d ","  --output-delimiter=",." -f 1-
}

_load_session(){
  if [[ ! -f "$CURRENT_SERVERS_CFG" ]]; then
    echo "No server found in the configuration, please at lease use command 'login' once."
    exit 1
  fi

  export bmc=$(yq ".bmc" "$CURRENT_SERVERS_CFG")
  auth_token=$(yq ".auth_token" "$CURRENT_SERVERS_CFG")
  location=$(yq ".location" "$CURRENT_SERVERS_CFG")

  CURL="curl -s -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'X-Auth-Token: ${auth_token}'"
  # if https, add -k
  if [[ "$bmc" == https* ]]; then
    CURL+=" -k"
  fi

  export CURL="eval $CURL"

  # if location is relative, add bmc to it
  if [[ "$location" != /* ]]; then
    location=$location
  else
    location="$bmc""$location"
  fi

  if [ "$($CURL -o /dev/null -w ''%{http_code}'' $location)" != "200" ]; then
    echo "session is invalid, please login again."
    exit 1
  fi

}

login(){
  local bmc_info=($parameters)

  if [ "${#bmc_info[@]}" -gt 2 ]; then
    local bmc="${bmc_info[0]}"
    local username="${bmc_info[1]}"
    local password="${bmc_info[2]}"

    local login_url="$bmc"/redfish/v1/SessionService/Sessions
    local login_body="{\"UserName\": \"$username\", \"Password\": \"$password\"}"
    
    local response=$(curl -k -s -i -X POST -H "Content-Type: application/json" -d "$login_body" "$login_url")
    #echo $response
    local session_id=$(echo "$response" | grep -i "X-Auth-Token" | awk '{print $2}' | tr -d $'\r')
    local location=$(echo "$response" | grep -i "Location" | awk '{print $2}' | tr -d $'\r')
    if [ -z "$session_id" ]; then
      echo "login failed, please check."
      exit 1
    fi

    _save_cfg "$bmc" "$session_id" "$location"
    _load_session
  else
    echo "command invalid, please try redfish-bash.sh login bmc username password"
    exit 1
  fi

}

#list all bmc servers saved in the config
servers(){
  echo
  echo "All servers in the list:"
  yq '.[]|(.index + "   "  + .bmc)' "$ALL_SERVERS_CFG"

  echo
  echo "use command 'server' to check the current server"
  echo "use command 'server N' to switch the servers"
}

#choose one of the bmc servers from the server list
server(){
  local index=$parameters
  if [ -n "$index" ]; then
    re='^[0-9]+$'
    if ! [[ $index =~ $re ]] ; then
      echo "error: $index not a number" >&2; exit 1
    fi
    if [[ $(yq ".[$index]" "$ALL_SERVERS_CFG") != "null" ]]; then
      echo "following server will be used:"
      yq ".[$index]" "$ALL_SERVERS_CFG"
      yq ".[$index]" "$ALL_SERVERS_CFG" > "$CURRENT_SERVERS_CFG"
    else
      echo "server with index $index not found"
    fi
  else
    echo "following server is being used:"
    yq "$CURRENT_SERVERS_CFG"
  fi

  export bmc=$(yq ".bmc" "$CURRENT_SERVERS_CFG")
  echo
}

_system(){
  if [ -z "$uuid" ]; then
    local system=$($CURL "$bmc/redfish/v1/Systems" | jq -r '.Members[0]."@odata.id"' )
  else
    local system=/redfish/v1/Systems/"$uuid"
  fi

  echo "$bmc""$system"
}

_manager(){
  if [ -z "$uuid" ]; then
    local manager=$($CURL "$bmc"/redfish/v1/Managers | jq -r '.Members[0]."@odata.id"' )
  else
    local manager=/redfish/v1/Managers/"$uuid"
  fi

  echo "$bmc""$manager"
}

system(){
  local system=$(_system)
  if [ -n "$parameters" ]; then
    attr=$(_pick $parameters)
    $CURL "$system" |jq -r "pick(.$attr)"
  else
    $CURL "$system" |jq
  fi

}

manager(){
  local manager=$(_manager)

  if [ -n "$parameters" ]; then
    attr=$(_pick $parameters)
    $CURL "$manager" |jq -r "pick(.$attr)"
  else
    $CURL "$manager" |jq
  fi
}

bmc-reboot(){
  local manager=$(_manager)
  local reset=$($CURL "$manager" |jq -r ".Actions.\"#Manager.Reset\".target")
  if [ -z "$reset" ] || [ "$reset" == "null" ]; then
    echo "Failed to get reset action from manager"
    exit -1
  fi

  local reset_type="ForceRestart"
  $CURL "--globoff  -L -w '%{http_code} %{url_effective}\\n' \
  -d '{\"ResetType\": \"${reset_type}\"}' \
  -X POST $bmc$reset"
}

bios(){
  local system=$(_system)
  local bios=$($CURL "$system"|jq -r '.Bios."@odata.id"')

  if [ -z "$bios" ] || [ "$bios" == "null" ]; then
    echo "Failed to get bios from system"
    exit -1
  fi

  if [ -n "$parameters" ]; then
    if [[ $parameters =~ "=" ]]; then
      #update bios settings
      local settings=$($CURL "$bmc""$bios" |jq -r ".\"@Redfish.Settings\".SettingsObject.\"@odata.id\"")
      local k_v=($(echo $parameters | cut -d "="  --output-delimiter=" " -f 1-))
      local key=${k_v[0]}
      local value=${k_v[1]}

      $CURL "--globoff  -L -w '%{http_code} %{url_effective}\\n' \
      -d '{\"Attributes\":{\"$key\": \"$value\"}}' \
      -X PATCH $bmc$settings"
    else
      #fetch bios settings
      attr=$(_pick $parameters)
      $CURL "$bmc""$bios" |jq -r "pick(.$attr)"
    fi
  else
    $CURL "$bmc""$bios" |jq
  fi
}

eths(){
  local system=$(_system)
  local ethernet_address=$($CURL "$system" |jq -r '.EthernetInterfaces."@odata.id"')
  local ethernetInterfaces=$($CURL "$bmc""$ethernet_address" |jq -r '.Members[]."@odata.id"')
  for ethernetInterface in $ethernetInterfaces; do
    $CURL "$bmc""$ethernetInterface" |jq
  done
}

power() {
  local system=$(_system)

  if [ -z "$parameters" ]; then
    $CURL "$system" |jq -r ".PowerState"
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
    if [ "nmi" = "$parameters" ]; then
      reset_type="Nmi"
    fi

    if [ -n "$reset_type" ]; then
      $CURL "--globoff  -L -w '%{http_code} %{url_effective}\\n' \
        -d '{\"ResetType\": \"${reset_type}\"}' \
        -X POST $system/Actions/ComputerSystem.Reset"
    else
      echo "$parameters is not valid command."
    fi
  fi
}

virtual-media(){
  local virtual_media_selected
  local manager=$(_manager)
  local system=$(_system)
  local virtual_medias=$($CURL "$manager"/"VirtualMedia" | jq -r '.Members[]."@odata.id"' 2>/dev/null)
  if [[ -z "$virtual_medias" ]]; then
    virtual_medias=$($CURL "$system"/"VirtualMedia" | jq -r '.Members[]."@odata.id"' 2>/dev/null)
  fi

  if [[ -z "$virtual_medias" ]]; then
    echo "Failed to get virtual media"
    return -1
  fi
  for virtual_media in $virtual_medias; do
    if [ $($CURL "$bmc""$virtual_media" | jq '.MediaTypes[]' |grep -ciE 'CD|DVD') -gt 0 ]; then
      virtual_media_selected=$virtual_media
      break
    fi
  done

  if [ -z "$parameters" ]; then
    $CURL " --globoff -X GET $bmc$virtual_media_selected"| jq
  else
    local virtual_media_ops=($parameters)
    local virtual_media_action="${virtual_media_ops[0]}"

    if [ "insert" = "$virtual_media_action" ]; then
      local iso_image="${virtual_media_ops[1]}"
      if [ -z "$iso_image" ]; then
        echo "Need to specify the ISO location."
      else
        $CURL " --globoff -L -w '%{http_code} %{url_effective}\\n' \
          -d '{\"Image\": \"${iso_image}\"}' \
          -X POST $bmc$virtual_media_selected/Actions/VirtualMedia.InsertMedia"
      fi
    fi

    if [ "eject" = "$virtual_media_action" ]; then
      $CURL " --globoff -L -w '%{http_code} %{url_effective}\\n' \
        -d '{}'  -X POST $bmc$virtual_media_selected/Actions/VirtualMedia.EjectMedia"
    fi
  fi
}

boot-once-from-cd() {
  local system=$(_system)

  if [ "$($CURL -o /dev/null -w ''%{http_code}'' $system/Settings)" != "200" ]; then
    $CURL " --globoff  -L -w '%{http_code} %{url_effective}\\n' \
    -d '{\"Boot\":{ \"BootSourceOverrideEnabled\": \"Once\", \"BootSourceOverrideTarget\": \"Cd\" }}' \
    -X PATCH $system"
  else
    $CURL " --globoff  -L -w '%{http_code} %{url_effective}\\n' \
    -d '{\"Boot\":{ \"BootSourceOverrideEnabled\": \"Once\", \"BootSourceOverrideTarget\": \"Cd\" }}' \
    -X PATCH $system/Settings"
  fi
}

secure-boot(){
  local system=$(_system)
  local secure_boot="$bmc"$($CURL "$system" |jq -r '.SecureBoot."@odata.id"')
  local enabled=$($CURL "$secure_boot" |jq -r ".SecureBootEnable")

  if [ -z "$parameters" ]; then
    echo "$enabled"
  else
    if [ $parameters = $enabled ]; then
      echo "secure boot is already $parameters, no need to change."
    else
      if [ "true" = "$parameters" ] || [ "false" = "$parameters" ]; then
        local body="{\"SecureBootEnable\":$parameters}"
        $CURL " -X PATCH -d '$body' $secure_boot"
        echo "secure boot has been set as $parameters, you may need to reboot the node to take effect."
      else
        echo "$parameters is not supported, it should be true or false"
      fi
    fi
  fi
}

storage(){
  local system=$(_system)
  local storage="$bmc"$($CURL "$system" |jq -r '.Storage."@odata.id"')
  if [ -n "$parameters" ]; then
    $CURL "$storage"/"$parameters" |jq
  else
    $CURL "$storage" |jq
  fi
}

root(){
  if [ -n "$parameters" ]; then
    attr=$(_pick $parameters)
    $CURL "$bmc"/redfish/v1 |jq -r "pick(.$attr)"
  else
    $CURL "$bmc"/redfish/v1 |jq
  fi
}

get(){
  if [ -n "$parameters" ]; then
    $CURL "$bmc"$parameters |jq
  else
    $CURL -sk "$bmc"/redfish/v1 |jq
  fi
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

if [ "login" = "$cmd" ]; then
  login
else
  _load_session

  $cmd
fi


