#!/bin/bash
#
#
umask 0066
NETRC="${HOME}/.bmc.netrc"

# Function to setup authentication
_setup_auth() {
  if [[ -f "$NETRC" ]]; then
    # Use NETRC file if it exists
    CURL="curl -k --netrc-file ${NETRC} ${REDFISH_CURL_OPTS}"
    AUTH_METHOD="netrc"
    [[ $(type -t _log) == function ]] && _log "DEBUG: _setup_auth() - Using NETRC authentication: $NETRC"
  else
    # Use default curl without authentication for initial setup
    # Authentication will be set when loading server config
    CURL="curl -k ${REDFISH_CURL_OPTS}"
    AUTH_METHOD="none"
    [[ $(type -t _log) == function ]] && _log "DEBUG: _setup_auth() - NETRC not found, using basic curl"
  fi
  [[ $(type -t _log) == function ]] && _log "DEBUG: _setup_auth() - AUTH_METHOD: $AUTH_METHOD"
}

if ! type "yq" > /dev/null; then
  echo "Cannot find yq in the path, please install yq on the node first. ref: https://github.com/mikefarah/yq#install"
  exit 1
fi

if ! type "jq" > /dev/null; then
  echo "Cannot find jq in the path, please install jq(1.7+) on the node first. ref: https://github.com/jqlang/jq?tab=readme-ov-file#installation"
  exit 1
fi

BASEDIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Setup authentication method
_setup_auth

ALL_SERVERS_CFG="$BASEDIR/.bmc-all.yaml"
CURRENT_SERVERS_CFG="$BASEDIR/.bmc-current.yaml"
touch "$ALL_SERVERS_CFG"

usage(){
  echo "Usage :   $0 command <parameters>"
  echo "Available commands: "
  echo "  -------------------------------------------"
  echo "  #login BMC (session-based authentication)"
  echo "  login <bmc_url> <username> <password>"
  echo "  #login BMC (legacy, requires NETRC or YAML)"
  echo "  login <bmc_url> [system_uuid]"
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
  echo "  get <redfish_path>"
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
  echo "  -------------------------------------------"
  echo "  #help"
  echo "  help"
  echo
  echo "Examples: "
  echo "  $0 login https://192.168.13.146 admin password123"
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
  echo "  $0 help"
  echo "Run : $0 login before using other commands for the first time."
  echo ""
  echo "Authentication methods (in order of preference):"
  echo "1. NETRC file: $NETRC (if exists, takes priority)"
  echo "   Format:"
  echo "   machine <BMC_HOST> login <USER_NAME> password <PASSWORD>"
  echo "   default login <USER_NAME> password <PASSWORD>"
  echo ""
  echo "2. Session token (via login command with username/password)"
  echo "   - Creates Redfish session and stores token"
  echo "   - Auto-refreshes when expired"
  echo ""
  echo "3. BMC YAML config: .bmc-all.yaml/.bmc-current.yaml (fallback method)"
  echo "   Format:"
  echo "   - index: 0"
  echo "     bmc: <BMC_URL>"
  echo "     userPass: <USER_NAME>:<PASSWORD>"
  echo "     authToken: <SESSION_TOKEN>   # auto-managed"
  echo "     location: <SESSION_URL>      # auto-managed"
  echo "     uuid: <SYSTEM_UUID>          # optional"

}

help(){
  usage
}

_log(){
  if [[ "true" == "$DEBUG" ]]; then
    echo "$@"
  fi
}

# Wrapper function for curl with session token authentication
_curl_session(){
  curl -s -H "X-Auth-Token: ${SESSION_TOKEN}" "$@"
}

_show_auth_method(){
  case "$AUTH_METHOD" in
    "netrc")
      echo "Using NETRC authentication: $NETRC"
      ;;
    "session")
      echo "Using session token authentication"
      ;;
    "yaml")
      echo "Using YAML authentication from config file"
      ;;
    "none")
      echo "Warning: No authentication method configured"
      ;;
    *)
      echo "Unknown authentication method: $AUTH_METHOD"
      ;;
  esac
}

# Function to validate if session token is still valid
_validate_token(){
  local auth_token=$(yq ".authToken" "$CURRENT_SERVERS_CFG" 2>/dev/null)
  local bmc_url=$(yq ".bmc" "$CURRENT_SERVERS_CFG" 2>/dev/null)
  
  _log "DEBUG: _validate_token() - Token: '${auth_token:0:10}...', BMC: '$bmc_url'"
  
  if [[ -n "$auth_token" && "$auth_token" != "null" && -n "$bmc_url" ]]; then
    # Test the token with an endpoint that requires authentication
    local test_url="$bmc_url/redfish/v1/AccountService"
    _log "DEBUG: _validate_token() - Testing token with URL: $test_url"
    
    local test_response=$(curl -s -H "X-Auth-Token: ${auth_token}" -k "$test_url" 2>/dev/null)
    _log "DEBUG: _validate_token() - Test response length: ${#test_response}"
    
    if echo "$test_response" | jq -e '.Id' >/dev/null 2>&1; then
      _log "DEBUG: _validate_token() - Token is valid"
      return 0  # Token is valid
    else
      # Check if it's a session error
      if echo "$test_response" | jq -e '.error."@Message.ExtendedInfo"[]? | select(.MessageId | test("NoValidSession"))' >/dev/null 2>&1; then
        _log "DEBUG: _validate_token() - Token is expired/invalid (NoValidSession)"
        return 1  # Token is invalid/expired
      else
        _log "DEBUG: _validate_token() - Other error, assuming token is valid"
        return 0  # Other error, assume token is valid
      fi
    fi
  else
    _log "DEBUG: _validate_token() - No token or BMC URL available"
    return 1  # No token available
  fi
}

# Function to refresh session token using stored credentials
_refresh_token(){
  local bmc_url=$(yq ".bmc" "$CURRENT_SERVERS_CFG" 2>/dev/null)
  local user_pass=$(yq ".userPass" "$CURRENT_SERVERS_CFG" 2>/dev/null)
  
  _log "DEBUG: _refresh_token() - BMC: '$bmc_url'"
  _log "DEBUG: _refresh_token() - userPass: '$user_pass'"
  
  # Extract username/password from userPass format
  if [[ -n "$user_pass" && "$user_pass" != "null" && "$user_pass" =~ ^[^:]+:.+ ]]; then
    local final_username=$(echo "$user_pass" | cut -d: -f1)
    local final_password=$(echo "$user_pass" | cut -d: -f2-)
    _log "DEBUG: _refresh_token() - Using userPass format, username: '$final_username'"
  else
    echo "Cannot refresh token: missing stored credentials."
    _log "DEBUG: _refresh_token() - No credentials found for token refresh"
    return 1
  fi
  
  if [[ -n "$bmc_url" && -n "$final_username" && -n "$final_password" ]]; then
    echo "Session token expired, refreshing with stored credentials..."
    local login_url="$bmc_url/redfish/v1/SessionService/Sessions"
    local login_body="{\"UserName\": \"$final_username\", \"Password\": \"$final_password\"}"
    
    _log "DEBUG: _refresh_token() - Login URL: $login_url"
    _log "DEBUG: _refresh_token() - Login body: {\"UserName\": \"$final_username\", \"Password\": \"[REDACTED]\"}"
    
    local response=$(curl -k -s -i -X POST -H "Content-Type: application/json" -d "$login_body" "$login_url")
    local session_id=$(echo "$response" | grep -i "^X-Auth-Token:" | awk '{print $2}' | tr -d $'\r')
    local location=$(echo "$response" | grep -i "^Location:" | awk '{print $2}' | tr -d $'\r')
    
    _log "DEBUG: _refresh_token() - New session ID: '$session_id'"
    _log "DEBUG: _refresh_token() - Session location: '$location'"
    
    if [ -n "$session_id" ]; then
      echo "Token refresh successful."
      _save_cfg "$bmc_url" "$session_id" "$location" "$final_username" "$final_password"
      return 0
    else
      echo "Token refresh failed."
      _log "DEBUG: _refresh_token() - Failed to extract session ID from response"
      return 1
    fi
  else
    echo "Cannot refresh token: missing stored credentials."
    return 1
  fi
}

# Reinitialize authentication based on stored server config
_reinit_auth_from_config(){
  _log "DEBUG: _reinit_auth_from_config() - Starting authentication reinitialization"
  if [[ -f "$CURRENT_SERVERS_CFG" ]]; then
    _log "DEBUG: _reinit_auth_from_config() - Current server config found: $CURRENT_SERVERS_CFG"
    if [[ -f "$NETRC" ]]; then
      # Use NETRC file if it exists
      CURL="curl -k --netrc-file ${NETRC} ${REDFISH_CURL_OPTS}"
      AUTH_METHOD="netrc"
      _log "DEBUG: _reinit_auth_from_config() - Using NETRC authentication: $NETRC"
    else
      # Check if we have a session token
      local auth_token=$(yq ".authToken" "$CURRENT_SERVERS_CFG" 2>/dev/null)
      _log "DEBUG: _reinit_auth_from_config() - Found authToken: '${auth_token:0:10}...'"
      
      if [[ -n "$auth_token" && "$auth_token" != "null" ]]; then
        # Validate the session token first
        _log "DEBUG: _reinit_auth_from_config() - Validating session token"
        if _validate_token; then
          # Token is valid, use it
          local bmc_url=$(yq ".bmc" "$CURRENT_SERVERS_CFG" 2>/dev/null)
          # Store token for use in _curl_session function
          export SESSION_TOKEN="$auth_token"
          if [[ "$bmc_url" == https* ]]; then
            CURL="_curl_session -k"
          else
            CURL="_curl_session"
          fi
          AUTH_METHOD="session"
          _log "DEBUG: _reinit_auth_from_config() - Using valid session token"
        else
          # Token is expired, try to refresh it
          _log "DEBUG: _reinit_auth_from_config() - Token expired, attempting refresh"
          if _refresh_token; then
            # Token refreshed successfully, reinitialize
            _log "DEBUG: _reinit_auth_from_config() - Token refreshed, reinitializing"
            _reinit_auth_from_config
            return
          else
            # Token refresh failed, fall back to userPass if available
            _log "DEBUG: _reinit_auth_from_config() - Token refresh failed, falling back to userPass"
            local user_pass=$(yq ".userPass" "$CURRENT_SERVERS_CFG" 2>/dev/null)
            if [[ -n "$user_pass" && "$user_pass" != "null" && "$user_pass" =~ ^[^:]+:.+ ]]; then
              CURL="curl -k -u ${user_pass} ${REDFISH_CURL_OPTS}"
              AUTH_METHOD="yaml"
              _log "DEBUG: _reinit_auth_from_config() - Using userPass fallback"
            else
              CURL="curl -k ${REDFISH_CURL_OPTS}"
              AUTH_METHOD="none"
              _log "DEBUG: _reinit_auth_from_config() - No fallback credentials available"
            fi
          fi
        fi
      else
        # Default to YAML authentication using userPass from config
        local user_pass=$(yq ".userPass" "$CURRENT_SERVERS_CFG" 2>/dev/null)
        _log "DEBUG: _reinit_auth_from_config() - No session token, checking userPass: '$user_pass'"
        
        if [[ -n "$user_pass" && "$user_pass" != "null" && "$user_pass" =~ ^[^:]+:.+ ]]; then
          # userPass format is username:password (primary format)
          CURL="curl -k -u ${user_pass} ${REDFISH_CURL_OPTS}"
          AUTH_METHOD="yaml"
          _log "DEBUG: _reinit_auth_from_config() - Using YAML authentication with userPass"
        else
          # No credentials available, use basic curl
          CURL="curl -k ${REDFISH_CURL_OPTS}"
          AUTH_METHOD="yaml"
          _log "DEBUG: _reinit_auth_from_config() - No credentials found, using basic curl"
        fi
      fi
    fi
  else
    _log "DEBUG: _reinit_auth_from_config() - No current server config, calling _setup_auth"
    _setup_auth
  fi
  _log "DEBUG: _reinit_auth_from_config() - Final AUTH_METHOD: $AUTH_METHOD"
}

_save_cfg(){
  export bmc=$1
  local auth_token=$2
  local location=$3
  local username=$4
  local password=$5
  
  index=$(yq ".[]|select(.bmc == \"$bmc\")|.index" "$ALL_SERVERS_CFG")
  if [ -z "$index" ]; then
    index=$(yq ".|length" "$ALL_SERVERS_CFG")
    if [ -n "$username" ] && [ -n "$password" ]; then
      # Store with userPass format for consistency
      yq -i ". += [{\"index\": ${index}, \"bmc\": \"$1\", \"userPass\": \"$username:$password\", \"authToken\": \"$auth_token\", \"location\": \"$location\"}]" "$ALL_SERVERS_CFG"
    else
      # Store without credentials (backward compatibility)
      yq -i ". += [{\"index\": ${index}, \"bmc\": \"$1\", \"authToken\": \"$auth_token\", \"location\": \"$location\"}]" "$ALL_SERVERS_CFG"
    fi
  else
    # Delete the element which index is $index
    yq -i "del(.[]|select(.index == ${index}))" "$ALL_SERVERS_CFG"
    if [ -n "$username" ] && [ -n "$password" ]; then
      # Update with userPass format for consistency
      yq -i ". += [{\"index\": ${index}, \"bmc\": \"$1\", \"userPass\": \"$username:$password\", \"authToken\": \"$auth_token\", \"location\": \"$location\"}]" "$ALL_SERVERS_CFG"
    else
      # Update without credentials (backward compatibility)
      yq -i ". += [{\"index\": ${index}, \"bmc\": \"$1\", \"authToken\": \"$auth_token\", \"location\": \"$location\"}]" "$ALL_SERVERS_CFG"
    fi
  fi

  # Order by index
  yq -i ". |= sort_by(.index)" "$ALL_SERVERS_CFG"

  yq ".[]|select(.index == ${index})" "$ALL_SERVERS_CFG" > "$CURRENT_SERVERS_CFG"
  cat "$CURRENT_SERVERS_CFG"
}

_pick(){
  echo $1 | cut -d ","  --output-delimiter=",." -f 1-
}

login(){
  local bmc_info=($parameters)
  _log "DEBUG: login() - Parameters: $parameters"
  _log "DEBUG: login() - BMC info array length: ${#bmc_info[@]}"

  if [ "${#bmc_info[@]}" -ge 3 ]; then
    # Session-based login: login <bmc> <username> <password>
    local bmc="${bmc_info[0]}"
    local username="${bmc_info[1]}"
    local password="${bmc_info[2]}"
    
    _log "DEBUG: login() - BMC: '$bmc', Username: '$username'"

    local login_url="$bmc"/redfish/v1/SessionService/Sessions
    local login_body="{\"UserName\": \"$username\", \"Password\": \"$password\"}"
    
    _log "DEBUG: login() - Login URL: $login_url"
    _log "DEBUG: login() - Login body: {\"UserName\": \"$username\", \"Password\": \"[REDACTED]\"}"
    
    local response=$(curl -k -s -i -X POST -H "Content-Type: application/json" -d "$login_body" "$login_url")
    local session_id=$(echo "$response" | grep -i "^X-Auth-Token:" | awk '{print $2}' | tr -d $'\r')
    local location=$(echo "$response" | grep -i "^Location:" | awk '{print $2}' | tr -d $'\r')
    
    _log "DEBUG: login() - Session ID: '$session_id'"
    _log "DEBUG: login() - Location: '$location'"
    
    if [ -z "$session_id" ]; then
      echo "login failed, please check credentials."
      _log "DEBUG: login() - Login failed - no session ID received"
      exit 1
    fi

    _save_cfg "$bmc" "$session_id" "$location" "$username" "$password"
    echo "login successful, will use this server for the following commands."
    # Reinitialize authentication to set up CURL with session token
    _reinit_auth_from_config
    _show_auth_method

  elif [ "${#bmc_info[@]}" -gt 0 ]; then
    # Legacy login with NETRC/YAML: login <bmc> [uuid]
    local bmc="${bmc_info[0]}"
    _log "DEBUG: login() - BMC URL: $bmc (legacy mode)"

    local redfish_url="$bmc"/redfish/v1/Systems/
    if [ "${#bmc_info[@]}" = 2 ]; then
      uuid="${bmc_info[1]}"
      redfish_url="$redfish_url$uuid"
      _log "DEBUG: login() - Using UUID: $uuid"
    fi
    _log "DEBUG: login() - Testing URL: $redfish_url"

    local http_code=$($CURL -k -s -o /dev/null -w ''%{http_code}'' "$redfish_url")
    _log "DEBUG: login() - HTTP response code: $http_code"
    
    if [ "$http_code" -eq 200 ]; then
      #login succeed
      echo "login successful (using NETRC/YAML auth), will use this server for the following commands."
      _show_auth_method
      _save_cfg "$bmc" "" "" "" ""
    else
      echo "login failed, please check. Try: login <bmc> <username> <password>"
      _log "DEBUG: login() - Login failed with HTTP code: $http_code"
      _show_auth_method
      exit 1
    fi

  else
    echo "Usage: redfish-bash.sh login <bmc_url> <username> <password>"
    echo "   or: redfish-bash.sh login <bmc_url> (requires NETRC or YAML credentials)"
    exit 1
  fi

}

#list all bmc servers saved in the config
servers(){
  echo
  echo "All servers in the list:"
  if [[ -f "$NETRC" ]]; then
    yq '.[]|(.index + "   "  + .bmc + " (netrc)")' "$ALL_SERVERS_CFG"
  else
    yq '.[]|(.index + "   "  + .bmc + " (yaml)")' "$ALL_SERVERS_CFG"
  fi

  echo
  echo "use command 'server' to check the current server"
  echo "use command 'server N' to switch the servers"
}

#choose one of the bmc servers from the server list
server(){
  local index=$parameters
  _log "DEBUG: server() - Index parameter: '$index'"
  
  if [ -n "$index" ]; then
    re='^[0-9]+$'
    if ! [[ $index =~ $re ]] ; then
      echo "error: $index not a number" >&2; exit 1
    fi
    _log "DEBUG: server() - Checking server at index $index"
    if [[ $(yq ".[$index]" "$ALL_SERVERS_CFG") != "null" ]]; then
      echo "following server will be used:"
      yq ".[$index]" "$ALL_SERVERS_CFG"
      yq ".[$index]" "$ALL_SERVERS_CFG" > "$CURRENT_SERVERS_CFG"
      _log "DEBUG: server() - Server config copied to current config"
      # Reinitialize authentication for the selected server
      _reinit_auth_from_config
      _show_auth_method
    else
      echo "server with index $index not found"
      _log "DEBUG: server() - Server with index $index not found in config"
    fi
  else
    echo "following server is being used:"
    yq "$CURRENT_SERVERS_CFG"
    # Reinitialize authentication for the current server
    _reinit_auth_from_config
    _show_auth_method
  fi

  export bmc=$(yq ".bmc" "$CURRENT_SERVERS_CFG")
  export uuid=$(yq ".uuid" "$CURRENT_SERVERS_CFG" 2>/dev/null)
  _log "DEBUG: server() - Exported BMC: '$bmc', UUID: '$uuid'"
  echo
}

_system(){
  _log "DEBUG: _system() - UUID: '$uuid', BMC: '$bmc'"
  if [ -z "$uuid" ] || [ "$uuid" = "null" ]; then
    _log "DEBUG: _system() - No UUID specified, getting first system from collection"
    local system=$($CURL -s "$bmc"/redfish/v1/Systems | jq -r '.Members[0]."@odata.id"' )
    _log "DEBUG: _system() - First system from collection: '$system'"
  else
    local system=/redfish/v1/Systems/"$uuid"
    _log "DEBUG: _system() - Using UUID-based system path: '$system'"
  fi
  
  local full_url="$bmc""$system"
  _log "DEBUG: _system() - Full system URL: '$full_url'"
  echo "$full_url"
}

_manager(){
  if [ -z "$uuid" ] || [ "$uuid" = "null" ]; then
    local manager=$($CURL -s "$bmc"/redfish/v1/Managers | jq -r '.Members[0]."@odata.id"' )
  else
    local manager=/redfish/v1/Managers/"$uuid"
  fi

  echo "$bmc""$manager"
}

system(){
  local system=$(_system)
  if [ -n "$parameters" ]; then
    attr=$(_pick $parameters)
    $CURL -s "$system" |jq -r "pick(.$attr)"
  else
    $CURL -s "$system" |jq
  fi

}

manager(){
  local manager=$(_manager)

  if [ -n "$parameters" ]; then
    attr=$(_pick $parameters)
    $CURL -s "$manager" |jq -r "pick(.$attr)"
  else
    $CURL -s "$manager" |jq
  fi
}

bmc-reboot(){
  local manager=$(_manager)
  local reset=$($CURL -s "$manager" |jq -r ".Actions.\"#Manager.Reset\".target")
  local reset_type="ForceRestart"
  $CURL --globoff  -L -w "%{http_code} %{url_effective}\\n" \
  -H "Content-Type: application/json" -H "Accept: application/json" \
  -d "{\"ResetType\": \"${reset_type}\"}" \
  -X POST "$bmc""$reset"
}

bios(){
  local system=$(_system)
  local bios=$($CURL -s "$system"|jq -r '.Bios."@odata.id"')

  if [ -n "$parameters" ]; then
    if [[ $parameters =~ "=" ]]; then
      #update bios settings
      local settings=$($CURL -s "$bmc""$bios" |jq -r ".\"@Redfish.Settings\".SettingsObject.\"@odata.id\"")
      local k_v=($(echo $parameters | cut -d "="  --output-delimiter=" " -f 1-))
      local key=${k_v[0]}
      local value=${k_v[1]}

      $CURL --globoff  -L -w "%{http_code} %{url_effective}\\n" \
      -H "Content-Type: application/json" -H "Accept: application/json" \
      -d "{\"Attributes\":{\"$key\": \"$value\"}}" \
      -X PATCH "$bmc""$settings"
    else
      #fetch bios settings
      attr=$(_pick $parameters)
      $CURL -s "$bmc""$bios" |jq -r "pick(.$attr)"
    fi
  else
    $CURL -s "$bmc""$bios" |jq
  fi
}

eths(){
  local system=$(_system)
  local ethernet_address=$($CURL -s "$system" |jq -r '.EthernetInterfaces."@odata.id"')
  local ethernetInterfaces=$($CURL -s "$bmc""$ethernet_address" |jq -r '.Members[]."@odata.id"')
  for ethernetInterface in $ethernetInterfaces; do
    $CURL -s "$bmc""$ethernetInterface" |jq
  done
}

power() {
  local system=$(_system)

  if [ -z "$parameters" ]; then
    $CURL -s "$system" |jq -r ".PowerState"
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
      $CURL --globoff  -L -w "%{http_code} %{url_effective}\\n" \
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
  local manager=$(_manager)
  local system=$(_system)
  local virtual_medias=$($CURL -s "$manager"/"VirtualMedia" | jq -r '.Members[]."@odata.id"' 2>/dev/null)
  if [[ -z "$virtual_medias" ]]; then
    virtual_medias=$($CURL -s "$system"/"VirtualMedia" | jq -r '.Members[]."@odata.id"' 2>/dev/null)
  fi

  if [[ -z "$virtual_medias" ]]; then
    echo "Failed to get virtual media"
    return -1
  fi
  for virtual_media in $virtual_medias; do
    if [ $($CURL -s "$bmc""$virtual_media" | jq '.MediaTypes[]' |grep -ciE 'CD|DVD') -gt 0 ]; then
      virtual_media_selected=$virtual_media
      break
    fi
  done

  if [ -z "$parameters" ]; then
    $CURL -s --globoff -H "Content-Type: application/json" -H "Accept: application/json" \
      -X GET "$bmc""$virtual_media_selected"| jq
  else
    local virtual_media_ops=($parameters)
    local virtual_media_action="${virtual_media_ops[0]}"

    if [ "insert" = "$virtual_media_action" ]; then
      local iso_image="${virtual_media_ops[1]}"
      if [ -z "$iso_image" ]; then
        echo "Need to specify the ISO location."
      else
        $CURL --globoff -L -w "%{http_code} %{url_effective}\\n" \
          -H "Content-Type: application/json" -H "Accept: application/json" \
          -d "{\"Image\": \"${iso_image}\"}" \
          -X POST "$bmc""$virtual_media_selected"/Actions/VirtualMedia.InsertMedia
      fi
    fi

    if [ "eject" = "$virtual_media_action" ]; then
      $CURL --globoff -L -w "%{http_code} %{url_effective}\\n" \
        -H "Content-Type: application/json" -H "Accept: application/json" \
        -d '{}'  -X POST "$bmc""$virtual_media_selected"/Actions/VirtualMedia.EjectMedia
    fi
  fi
}

boot-once-from-cd() {
  local system=$(_system)
  if [[ -z $($CURL --globoff -sk $system/Settings| jq -r '.Boot["BootSourceOverrideTarget@Redfish.AllowableValues"] // empty') ]]; then
    $CURL --globoff  -L -w "%{http_code} %{url_effective}\\n" \
    -H "Content-Type: application/json" -H "Accept: application/json" \
    -d '{"Boot":{ "BootSourceOverrideEnabled": "Once", "BootSourceOverrideTarget": "Cd" }}' \
    -X PATCH $system
  else
    $CURL --globoff  -L -w "%{http_code} %{url_effective}\\n" \
    -H "Content-Type: application/json" -H "Accept: application/json" \
    -d '{"Boot":{ "BootSourceOverrideEnabled": "Once", "BootSourceOverrideTarget": "Cd" }}' \
    -X PATCH $system/Settings
  fi
}

secure-boot(){
  local system=$(_system)
  local secure_boot="$bmc"$($CURL -s "$system" |jq -r '.SecureBoot."@odata.id"')
  local enabled=$($CURL -s "$secure_boot" |jq -r ".SecureBootEnable")

  if [ -z "$parameters" ]; then
    echo "$enabled"
  else
    if [ $parameters = $enabled ]; then
      echo "secure boot is already $parameters, no need to change."
    else
      if [ "true" = "$parameters" ] || [ "false" = "$parameters" ]; then
        local body="{\"SecureBootEnable\":$parameters}"
        $CURL -s -X PATCH -H "Content-Type: application/json" -d "$body" "$secure_boot"
        echo "secure boot has been set as $parameters, you may need to reboot the node to take effect."
      else
        echo "$parameters is not supported, it should be true or false"
      fi
    fi
  fi
}

storage(){
  local system=$(_system)
  local storage="$bmc"$($CURL -s "$system" |jq -r '.Storage."@odata.id"')
  if [ -n "$parameters" ]; then
    $CURL -s "$storage"/"$parameters" |jq
  else
    $CURL -s "$storage" |jq
  fi
}

root(){
  if [ -n "$parameters" ]; then
    attr=$(_pick $parameters)
    $CURL -s "$bmc"/redfish/v1 |jq -r "pick(.$attr)"
  else
    $CURL -s "$bmc"/redfish/v1 |jq
  fi
}

get(){
  if [ -n "$parameters" ]; then
    $CURL -s "$bmc"$parameters |jq
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
  if [[ ! -f "$CURRENT_SERVERS_CFG" ]]; then
    echo "No server found in the configuration, please at least use command 'login' once."
    exit 1
  fi

  # Reinitialize authentication based on stored server config
  _reinit_auth_from_config
  export bmc=$(yq ".bmc" "$CURRENT_SERVERS_CFG")
  export uuid=$(yq ".uuid" "$CURRENT_SERVERS_CFG" 2>/dev/null)

  $cmd
fi

