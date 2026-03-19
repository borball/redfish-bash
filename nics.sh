#!/usr/bin/env bash
#
# nics.sh - Fetch NIC information from a BMC via Redfish API.
# Displays a card view similar to the BMC "Host / Hardware / Network" page
# (e.g. HPE iLO 7): each NIC with Model, State, Health, Location, SKU,
# Firmware Version, Number Of Ports.
#
# Invocation (only via redfish-bash; uses current server from login / server N):
#   redfish-bash.sh nics
#   redfish-bash.sh nics --json
#   redfish-bash.sh nics --json -o nics.json
#
# Options:
#   --json          Output raw JSON only (no card view)
#   -o FILE         Write JSON to FILE
#
set -e

# Ensure we run with bash (script uses [[, =~, BASH_REMATCH, etc.)
if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "Error: this script requires bash. Run with: bash $0 ..." >&2
  exit 1
fi

OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)      OUTPUT_JSON=true; shift ;;
    -o)          OUT_FILE="$2"; shift 2 ;;
    -h|--help)
      sed -n '1,45p' "$0" | grep -E '^# |^#Usage|^#   |^#Options' | sed 's/^# \?//'
      exit 0
      ;;
    *)           echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "${bmc:-}" ]] || ! declare -F _redfish_nics_http_get &>/dev/null || ! declare -F _redfish_bmc_v1_root &>/dev/null; then
  echo "Error: nics.sh is only supported via: redfish-bash.sh nics [...]" >&2
  exit 1
fi
BASE_URL="$(_redfish_bmc_v1_root)"

# --- Helpers: PCI BDF and UEFI path ---
# Build BDF string from bus, device, function (decimal). Output in PCI_ADDR (global) when successful.
_bdf_from_bdf() {
  local b="$1" d="${2:-0}" f="${3:-0}"
  [[ -z "$b" || "$b" == "null" ]] && return 1
  printf -v PCI_ADDR "0000:%02x:%02x.%x" "$((10#$b))" "$((10#$d))" "$((10#$f))"
  return 0
}

# Parse UEFI device path (e.g. PciRoot(0x40)/Pci(0x4,0x0) or .../Pci(0x1,0x0)/Pci(0x0,0x0)) to BDF.
# Sets PCI_ADDR and returns 0 on success.
_uefi_path_to_bdf() {
  local uefi_path="$1"
  local bus devfn dev fun last_pci
  [[ -z "$uefi_path" || "$uefi_path" == "null" ]] && return 1
  if [[ "$uefi_path" =~ PciRoot\(0x([0-9A-Fa-f]+)\)/Pci\(0x([0-9A-Fa-f]+),0x([0-9A-Fa-f]+)\) ]]; then
    bus="${BASH_REMATCH[2]}"; devfn="${BASH_REMATCH[3]}"
    dev=$((0x$devfn >> 3)); fun=$((0x$devfn & 0x7))
    printf -v PCI_ADDR "0000:%02x:%02x.%x" $((0x$bus)) "$dev" "$fun"
    return 0
  fi
  last_pci="$(echo "$uefi_path" | grep -oE 'Pci\(0x[0-9A-Fa-f]+,0x[0-9A-Fa-f]+\)' | tail -1)"
  if [[ -n "$last_pci" && "$last_pci" =~ Pci\(0x([0-9A-Fa-f]+),0x([0-9A-Fa-f]+)\) ]]; then
    bus="${BASH_REMATCH[1]}"; devfn="${BASH_REMATCH[2]}"
    dev=$((0x$devfn >> 3)); fun=$((0x$devfn & 0x7))
    printf -v PCI_ADDR "0000:%02x:%02x.%x" $((0x$bus)) "$dev" "$fun"
    return 0
  fi
  return 1
}

# --- Redfish root and Chassis ---
ROOT="$(_redfish_nics_http_get /redfish/v1)"
if ! echo "$ROOT" | jq -e . >/dev/null 2>&1; then
  echo "Error: Redfish root request failed or returned invalid JSON. Check credentials, network, and login/session." >&2
  [[ -n "$ROOT" && "${#ROOT}" -lt 200 ]] && echo "Response preview: $ROOT" >&2
  exit 1
fi
CHASSIS_URI="$(echo "$ROOT" | jq -r '.Chassis["@odata.id"] // .chassis["@odata.id"] // empty')"
if [[ -z "$CHASSIS_URI" || "$CHASSIS_URI" == "null" ]]; then
  # Some roots omit Chassis link; try the standard Chassis collection path directly
  CHASSIS_COLL="$(_redfish_nics_http_get /redfish/v1/Chassis)"
  if echo "$CHASSIS_COLL" | jq -e '.Members | length > 0' >/dev/null 2>&1 || echo "$CHASSIS_COLL" | jq -e '.["@odata.id"]' >/dev/null 2>&1; then
    CHASSIS_URI="/redfish/v1/Chassis"
  else
    echo "Error: Redfish root has no Chassis and /redfish/v1/Chassis is not available." >&2
    exit 1
  fi
fi

CHASSIS_COLL="$(_redfish_nics_http_get "$CHASSIS_URI")"
MEMBERS_JSON="$(echo "$CHASSIS_COLL" | jq -r '.Members[]? | .["@odata.id"] // .url // empty' 2>/dev/null)"
if [[ -z "$MEMBERS_JSON" ]]; then
  echo "No chassis members found."
  exit 1
fi

# --- Chassis and NetworkAdapters (per chassis) ---
NICS_JSON_ARRAY="[]"
while IFS= read -r ch_uri; do
  if [[ -z "$ch_uri" ]]; then continue; fi
  ch_uri="${ch_uri%/}"
  CH="$(_redfish_nics_http_get "$ch_uri")"
  # Dell: Oem/Dell/DellNIC under chassis (e.g. /redfish/v1/Chassis/System.Embedded.1/Oem/Dell/DellNIC)
  # Response: collection with Members[] (each @odata.id -> .../DellNIC/NIC.Embedded.4-1-1), or inline objects.
  # Each DellNIC object: FQDD, InstanceID, BusNumber, FunctionNumber, SerialNumber, DeviceDescription, NumberOfPorts.
  DELL_NIC_JSON=""
  DELL_NIC_URI="${ch_uri}/Oem/Dell/DellNIC"
  _tmp="$(_redfish_nics_http_get "$DELL_NIC_URI")"
  if [[ -n "$_tmp" && "$_tmp" != "{}" && "$_tmp" != "null" ]] && echo "$_tmp" | jq -e . >/dev/null 2>&1 && ! echo "$_tmp" | jq -e '.error' >/dev/null 2>&1; then
    # If Members exist and first member lacks BusNumber (links only), fetch each member
    _first_has_bus="$(echo "$_tmp" | jq -r '.Members[0].BusNumber // empty' 2>/dev/null)"
    if [[ -z "$_first_has_bus" ]] && echo "$_tmp" | jq -e '.Members[]?' >/dev/null 2>&1; then
      _dell_nic_list="[]"
      while IFS= read -r member_uri; do
        if [[ -z "$member_uri" ]]; then continue; fi
        _m="$(_redfish_nics_http_get "$member_uri")"
        _dell_nic_list="$(echo "$_dell_nic_list" | jq --argjson m "$_m" '. + [$m]' 2>/dev/null)"
      done <<< "$(echo "$_tmp" | jq -r '.Members[]? | .["@odata.id"] // empty' 2>/dev/null)"
      [[ -n "$_dell_nic_list" && "$_dell_nic_list" != "[]" ]] && DELL_NIC_JSON="$_dell_nic_list"
    fi
    [[ -z "$DELL_NIC_JSON" ]] && DELL_NIC_JSON="$_tmp"
  fi
  unset _tmp _dell_nic_list _m _first_has_bus
  # HPE: Chassis/PCIeSlots has Slots[].Location.PartLocation.ServiceLabel (e.g. "OCP Slot A") and LocationOrdinalValue
  # Use to resolve raw adapter Id (DE07A000) to friendly slot name when adapter has no Location/Oem
  PCIE_SLOTS_JSON=""
  _ps="$(_redfish_nics_http_get "${ch_uri}/PCIeSlots")"
  if [[ -n "$_ps" && "$_ps" != "{}" && "$_ps" != "null" ]] && echo "$_ps" | jq -e '(.Slots | length > 0) or (.Members | length > 0)' >/dev/null 2>&1; then
    PCIE_SLOTS_JSON="$_ps"
  fi
  unset _ps
  NA_REF="$(echo "$CH" | jq -r '.NetworkAdapters["@odata.id"] // empty')"
  if [[ -z "$NA_REF" || "$NA_REF" == "null" ]]; then
    echo "bmc-nic-builder: chassis $ch_uri has no NetworkAdapters link, skipping."
    continue
  fi
  NA_COLL="$(_redfish_nics_http_get "$NA_REF")"
  ADAPTER_IDS="$(echo "$NA_COLL" | jq -r '.Members[]? | .["@odata.id"] // .url // empty' 2>/dev/null)"
  if [[ -z "$ADAPTER_IDS" ]]; then
    echo "bmc-nic-builder: NetworkAdapters collection has no Members: $NA_REF"
  fi
  # Track BDFs already assigned from HPE Systems/PCIDevices name match so multiple same-model NICs get distinct addresses
  HPE_PCI_USED_BDFS=""
  while IFS= read -r adapter_uri; do
    if [[ -z "$adapter_uri" ]]; then continue; fi
    ADAPTER="$(_redfish_nics_http_get "$adapter_uri")"
    # Extract fields to match BMC view + hardware info (standard + Oem.Dell, Oem.Hpe)
    MODEL="$(echo "$ADAPTER" | jq -r '.Model // .Name // "Unknown"')"
    STATE="$(echo "$ADAPTER" | jq -r '.Status.State // .Oem.Dell.NetworkAdapterStatus // .Oem.Dell.State // .Oem.Hpe.State // "Unknown"')"
    HEALTH="$(echo "$ADAPTER" | jq -r '.Status.Health // .Status.HealthRollup // .Oem.Dell.Health // .Oem.Dell.HealthRollup // .Oem.Hpe.Health // "Unknown"')"
    SKU="$(echo "$ADAPTER" | jq -r '.SKU // .Oem.Dell.SKU // .Oem.Hpe.SKU // ""')"
    FW="$(echo "$ADAPTER" | jq -r '.FirmwareVersion // ""')"
    SERIAL="$(echo "$ADAPTER" | jq -r '.SerialNumber // .Oem.Dell.SerialNumber // .Oem.Hpe.SerialNumber // ""')"
    PART="$(echo "$ADAPTER" | jq -r '.PartNumber // .Oem.Dell.PartNumber // .Oem.Hpe.PartNumber // ""')"
    MFR="$(echo "$ADAPTER" | jq -r '.Manufacturer // .Oem.Dell.Manufacturer // .Oem.Hpe.Manufacturer // ""')"
    # Firmware from first controller if not on adapter
    if [[ -z "$FW" || "$FW" == "null" ]]; then
      FW="$(echo "$ADAPTER" | jq -r '.Controllers[0].FirmwarePackageVersion // .Controllers[0].FirmwareVersion // ""')"
    fi
    # --- Location (human-readable slot/label) ---
    LOCATION="$(echo "$ADAPTER" | jq -r '
      .Oem.Hpe.Location // .Oem.Hpe.ServiceLabel //
      .Oem.Dell.Location // .Oem.Dell.ServiceLabel //
      .Location.PartLocation.ServiceLabel // .Location.Placement.Rack //
      .Controllers[0].Location.PartLocation.ServiceLabel //
      .Id // "Unknown"
    ')"
    # --- PCI address (BDF): Chassis PCIeDevice, then HPE Systems/PCI(e)Devices, UEFI path, Dell ---
    PCI_ADDR=""
    set +e
    PCIE_REF="$(echo "$ADAPTER" | jq -r '.Links.PCIeDevice["@odata.id"] // .Links.PCIeDevices[0]["@odata.id"] // .Controllers[0].Links.PCIeDevice["@odata.id"] // .Controllers[0].Links.PCIeDevices[0]["@odata.id"] // empty')"
    if [[ -n "$PCIE_REF" && "$PCIE_REF" != "null" ]]; then
      PCIE_JSON="$(_redfish_nics_http_get "$PCIE_REF")"
      # PCIeDevice can have PCIeFunctions (array) or single PCIeInterface with Bus/Device/Function (HPE often omits BusNumber for OCP)
      B="$(echo "$PCIE_JSON" | jq -r '(.PCIeInterface.BusNumber // .PCIeFunctions[0].PCIeInterface.BusNumber // .BusNumber // empty) | tostring' 2>/dev/null)"
      D="$(echo "$PCIE_JSON" | jq -r '(.PCIeInterface.DeviceNumber // .PCIeFunctions[0].PCIeInterface.DeviceNumber // .DeviceNumber // 0) | tostring' 2>/dev/null)"
      F="$(echo "$PCIE_JSON" | jq -r '(.PCIeInterface.FunctionNumber // .PCIeFunctions[0].PCIeInterface.FunctionNumber // .FunctionNumber // 0) | tostring' 2>/dev/null)"
      _bdf_from_bdf "$B" "$D" "$F" || true
      # Try each PCIeFunction if top-level had no BusNumber (e.g. HPE OCP card)
      if [[ -z "$PCI_ADDR" || "$PCI_ADDR" == "null" ]]; then
        _nf="$(echo "$PCIE_JSON" | jq -r '(.PCIeFunctions | length) // 0' 2>/dev/null)" || _nf=0
        _nf="${_nf:-0}"
        for (( _fi=0; _fi < _nf; _fi++ )); do
          B="$(echo "$PCIE_JSON" | jq -r "(.PCIeFunctions[$_fi].PCIeInterface.BusNumber // .PCIeFunctions[$_fi].BusNumber // empty) | tostring" 2>/dev/null)"
          if [[ -n "$B" && "$B" != "null" ]]; then
            D="$(echo "$PCIE_JSON" | jq -r "(.PCIeFunctions[$_fi].PCIeInterface.DeviceNumber // .PCIeFunctions[$_fi].DeviceNumber // 0) | tostring" 2>/dev/null)"
            F="$(echo "$PCIE_JSON" | jq -r "(.PCIeFunctions[$_fi].PCIeInterface.FunctionNumber // .PCIeFunctions[$_fi].FunctionNumber // 0) | tostring" 2>/dev/null)"
            if _bdf_from_bdf "$B" "${D:-0}" "${F:-0}"; then break; fi
          fi
        done
      fi
      # HPE: PCIeDevice resource sometimes has Oem.Hpe.UEFIDevicePath when BusNumber is omitted (e.g. OCP)
      if [[ -z "$PCI_ADDR" || "$PCI_ADDR" == "null" ]]; then
        UEFI_PATH="$(echo "$PCIE_JSON" | jq -r '.Oem.Hpe.UEFIDevicePath // ""' 2>/dev/null)" || UEFI_PATH=""
        _uefi_path_to_bdf "$UEFI_PATH" || true
      fi
      # Slot string (e.g. "Slot 7") as fallback only if it looks like a slot label, not a Redfish device Id (e.g. DDT0A000)
      if [[ -z "$PCI_ADDR" ]]; then
        _slot="$(echo "$PCIE_JSON" | jq -r '.Slot // .PCIeInterface.Slot // ""' 2>/dev/null)" || _slot=""
        if [[ -n "$_slot" && "$_slot" != "null" ]]; then
          if [[ "$_slot" =~ ^0000:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}\.[0-7]$ ]] || [[ "$_slot" =~ ^Slot\ [0-9]+$ ]] || [[ "$_slot" =~ ^[0-9]+$ ]]; then
            PCI_ADDR="$_slot"
          fi
        fi
        unset _slot
      fi
    fi
    # HPE: try Systems/PCIeDevices or Systems/PCIDevices before UEFI so multiple same-model NICs (e.g. two E825-C or two E830) get distinct BDFs
    if [[ -z "$PCI_ADDR" || "$PCI_ADDR" == "null" ]]; then
      SYS_URI="$(echo "$CH" | jq -r '.Links.ComputerSystems[0]["@odata.id"] // .ComputerSystems[0]["@odata.id"] // empty' 2>/dev/null)" || SYS_URI=""
      if [[ -n "$SYS_URI" && "$SYS_URI" != "null" ]]; then
        SYS_PCIE_COLL="$(_redfish_nics_http_get "${SYS_URI}/PCIeDevices")"
        if [[ -z "$SYS_PCIE_COLL" || "$SYS_PCIE_COLL" == "{}" ]] || echo "$SYS_PCIE_COLL" | jq -e '.error' >/dev/null 2>&1; then
          SYS_PCIE_COLL=""
        fi
        if [[ -n "$SYS_PCIE_COLL" ]] && echo "$SYS_PCIE_COLL" | jq -e '.Members[]?' >/dev/null 2>&1; then
          ADAPTER_ID_PCIE="${adapter_uri##*/}"
          set +e
          while IFS= read -r _pcie_dev_uri; do
            if [[ -z "$_pcie_dev_uri" ]]; then continue; fi
            _pcie_dev="$(_redfish_nics_http_get "$_pcie_dev_uri")"
            _dev_id="$(echo "$_pcie_dev" | jq -r '.Id // ""' 2>/dev/null)"
            _dev_serial="$(echo "$_pcie_dev" | jq -r '.SerialNumber // .Oem.Hpe.SerialNumber // ""' 2>/dev/null)"
            _match=false
            if [[ "$_dev_id" == "$ADAPTER_ID_PCIE" ]]; then _match=true; fi
            if [[ "$_match" != true && -n "$SERIAL" && "$SERIAL" != "null" && "$_dev_serial" == "$SERIAL" ]]; then _match=true; fi
            if [[ "$_match" == true ]]; then
              _pb="$(echo "$_pcie_dev" | jq -r '.BusNumber // .PCIeInterface.BusNumber // empty' 2>/dev/null)"
              if [[ -n "$_pb" && "$_pb" != "null" ]]; then
                _pd="$(echo "$_pcie_dev" | jq -r '.DeviceNumber // .PCIeInterface.DeviceNumber // 0' 2>/dev/null)"
                _pf="$(echo "$_pcie_dev" | jq -r '.FunctionNumber // .PCIeInterface.FunctionNumber // 0' 2>/dev/null)"
                if _bdf_from_bdf "$_pb" "${_pd:-0}" "${_pf:-0}"; then
                  set -e
                  unset _pcie_dev_uri _pcie_dev _dev_id _dev_serial _pb _pd _pf
                  break
                fi
              fi
            fi
          done <<< "$(echo "$SYS_PCIE_COLL" | jq -r '.Members[]? | .["@odata.id"] // empty' 2>/dev/null)"
          set -e
          unset ADAPTER_ID_PCIE
        fi
        if [[ -z "$PCI_ADDR" || "$PCI_ADDR" == "null" ]]; then
          SYS_PCI_COLL="$(_redfish_nics_http_get "${SYS_URI}/PCIDevices")"
          if [[ -n "$SYS_PCI_COLL" && "$SYS_PCI_COLL" != "{}" ]] && ! echo "$SYS_PCI_COLL" | jq -e '.error' >/dev/null 2>&1; then
            if echo "$SYS_PCI_COLL" | jq -e '.Members[]?' >/dev/null 2>&1; then
              _model_sig="$(echo "$MODEL" | grep -oE 'E[0-9]{3}' | head -1)" || _model_sig=""
              set +e
              if [[ -n "$SERIAL" && "$SERIAL" != "null" ]]; then
                while IFS= read -r _pci_dev_uri; do
                  if [[ -z "$_pci_dev_uri" ]]; then continue; fi
                  _pci_dev="$(_redfish_nics_http_get "$_pci_dev_uri")"
                  _pci_serial="$(echo "$_pci_dev" | jq -r '.SerialNumber // .Oem.Hpe.SerialNumber // ""' 2>/dev/null)"
                  if [[ "$_pci_serial" == "$SERIAL" ]]; then
                    _pb="$(echo "$_pci_dev" | jq -r '.BusNumber // empty' 2>/dev/null)"
                    if [[ -n "$_pb" && "$_pb" != "null" ]]; then
                      _pd="$(echo "$_pci_dev" | jq -r '.DeviceNumber // 0' 2>/dev/null)"
                      _pf="$(echo "$_pci_dev" | jq -r '.FunctionNumber // 0' 2>/dev/null)"
                      if _bdf_from_bdf "$_pb" "${_pd:-0}" "${_pf:-0}"; then break; fi
                    fi
                  fi
                done <<< "$(echo "$SYS_PCI_COLL" | jq -r '.Members[]? | .["@odata.id"] // empty' 2>/dev/null)"
              fi
              if [[ -z "$PCI_ADDR" || "$PCI_ADDR" == "null" ]] && [[ -n "$_model_sig" ]]; then
                while IFS= read -r _pci_dev_uri; do
                  if [[ -z "$_pci_dev_uri" ]]; then continue; fi
                  _pci_dev="$(_redfish_nics_http_get "$_pci_dev_uri")"
                  _pb="$(echo "$_pci_dev" | jq -r '.BusNumber // empty' 2>/dev/null)"
                  if [[ -z "$_pb" || "$_pb" == "null" ]]; then continue; fi
                  _pci_name="$(echo "$_pci_dev" | jq -r '.Name // ""' 2>/dev/null)"
                  if [[ -z "$_pci_name" || "$_pci_name" != *"$_model_sig"* ]]; then continue; fi
                  _pd="$(echo "$_pci_dev" | jq -r '.DeviceNumber // 0' 2>/dev/null)"
                  _pf="$(echo "$_pci_dev" | jq -r '.FunctionNumber // 0' 2>/dev/null)"
                  _pd="${_pd:-0}"; _pf="${_pf:-0}"
                  if _bdf_from_bdf "$_pb" "${_pd:-0}" "${_pf:-0}"; then
                    if [[ " ${HPE_PCI_USED_BDFS} " == *" ${PCI_ADDR} "* ]]; then continue; fi
                    HPE_PCI_USED_BDFS="${HPE_PCI_USED_BDFS} ${PCI_ADDR}"
                    break
                  fi
                done <<< "$(echo "$SYS_PCI_COLL" | jq -r '.Members[]? | .["@odata.id"] // empty' 2>/dev/null)"
              fi
              set -e
            fi
          fi
        fi
      fi
      unset SYS_URI
    fi
    if [[ -z "$PCI_ADDR" || "$PCI_ADDR" == "null" ]]; then
      UEFI_PATH="$(echo "$ADAPTER" | jq -r '.Oem.Hpe.UEFIDevicePath // ""' 2>/dev/null)" || true
      if [[ -z "$UEFI_PATH" || "$UEFI_PATH" == "null" ]]; then
        _nc="$(echo "$ADAPTER" | jq -r '(.Controllers | length) // 0' 2>/dev/null)" || _nc=0
        _nc="${_nc:-0}"
        for (( _ci=0; _ci < _nc; _ci++ )); do
          UEFI_PATH="$(echo "$ADAPTER" | jq -r ".Controllers[$_ci].Oem.Hpe.UEFIDevicePath // \"\"" 2>/dev/null)" || UEFI_PATH=""
          [[ -n "$UEFI_PATH" && "$UEFI_PATH" != "null" ]] && break
        done
      fi
      _uefi_path_to_bdf "$UEFI_PATH" || true
    fi
    if [[ -z "$PCI_ADDR" || "$PCI_ADDR" == "null" ]]; then
      PCI_ADDR="$(echo "$ADAPTER" | jq -r '.Oem.Dell.PCIeDeviceLocation // .Oem.Dell.PCIAddress // ""' 2>/dev/null)" || PCI_ADDR=""
    fi
    set -e
    # Enrich from Dell Oem/Dell/DellNIC when available (DellNIC has BusNumber, FunctionNumber, SerialNumber, DeviceDescription)
    if [[ -n "$DELL_NIC_JSON" ]]; then
      ADAPTER_ID="${adapter_uri##*/}"
      # Match by Id/FQDD/InstanceID, then by SerialNumber, then by Location/DeviceDescription (Dell may use NIC.Slot.2, NIC.Embedded.1)
      DELL_ENTRY="$(echo "$DELL_NIC_JSON" | jq -c --arg id "$ADAPTER_ID" --arg serial "$SERIAL" --arg loc "$LOCATION" '
        (if .Members then .Members elif type == "array" then . else [.] end) |
        .[] |
        select(
          .Id == $id or .FQDD == $id or .InstanceID == $id or (.["@odata.id"] // "" | split("/") | last == $id) or
          ($serial != "" and $serial != "null" and ((.SerialNumber // .Serial // "") == $serial)) or
          ($loc != "" and $loc != "Unknown" and ((.DeviceDescription // .Slot // .Location // "") == $loc or ((.DeviceDescription // "") | index($loc)) != null)) or
          ($loc != "" and ($loc | ascii_downcase | index("embedded")) != null and ((.DeviceDescription // .Slot // .Location // "") | ascii_downcase | index("embedded")) != null)
        )
      ' 2>/dev/null | head -1)"
      if [[ -n "$DELL_ENTRY" && "$DELL_ENTRY" != "null" ]]; then
        if [[ -z "$LOCATION" || "$LOCATION" == "Unknown" ]]; then
          LOCATION="$(echo "$DELL_ENTRY" | jq -r '.DeviceDescription // .Slot // .Location // .ServiceTag // .Name // ""')"
        fi
        if [[ -z "$PCI_ADDR" ]]; then
          PCI_ADDR="$(echo "$DELL_ENTRY" | jq -r '.PCIAddress // .PCIeAddress // ""')"
          if [[ -z "$PCI_ADDR" || "$PCI_ADDR" == "null" ]]; then
            _b="$(echo "$DELL_ENTRY" | jq -r '.BusNumber // empty')"
            _d="$(echo "$DELL_ENTRY" | jq -r '.DeviceNumber // 0')"
            _f="$(echo "$DELL_ENTRY" | jq -r '.FunctionNumber // 0')"
            _bdf_from_bdf "$_b" "${_d:-0}" "${_f:-0}" || true
          fi
        fi
        if [[ -z "$SERIAL" || "$SERIAL" == "null" ]]; then
          SERIAL="$(echo "$DELL_ENTRY" | jq -r '.SerialNumber // .Serial // ""')"
        fi
      fi
    fi
    # HPE: resolve raw Id (DE07A000) to slot name from Chassis/PCIeSlots (e.g. LocationOrdinalValue 7 -> "OCP Slot A")
    if [[ -n "$PCIE_SLOTS_JSON" ]] && { [[ -z "$LOCATION" || "$LOCATION" == "Unknown" ]] || [[ "$LOCATION" =~ ^DE[0-9A-Fa-f][0-9A-Fa-f] ]]; }; then
      # Adapter Id (e.g. DE07A000) often encodes slot ordinal in 3rd/4th chars (07 -> 7) on HPE
      ADAPTER_ID_FOR_SLOT="${adapter_uri##*/}"
      if [[ "$ADAPTER_ID_FOR_SLOT" =~ ^DE([0-9A-Fa-f][0-9A-Fa-f]) ]]; then
        ORDINAL="$((0x${BASH_REMATCH[1]}))"
        SLOT_LABEL="$(echo "$PCIE_SLOTS_JSON" | jq -r --argjson ord "$ORDINAL" '
          (.Slots[]? | select(.Location.PartLocation.LocationOrdinalValue == $ord) | .Location.PartLocation.ServiceLabel) //
          (.Members[]? | select(.Location.PartLocation.LocationOrdinalValue == $ord) | .Location.PartLocation.ServiceLabel) //
          empty
        ' 2>/dev/null | head -1)"
        if [[ -n "$SLOT_LABEL" && "$SLOT_LABEL" != "null" ]]; then
          LOCATION="$SLOT_LABEL"
        fi
      fi
      # Fallback: single OCP slot (SlotType OCP3Small) -> use when location still raw
      if [[ "$LOCATION" =~ ^DE[0-9A-Fa-f][0-9A-Fa-f] ]]; then
        OCP_LABEL="$(echo "$PCIE_SLOTS_JSON" | jq -r '
          (.Slots[]? | select(.SlotType == "OCP3Small" or (.SlotType | type == "string" and test("OCP"))) | .Location.PartLocation.ServiceLabel) //
          (.Members[]? | select(.SlotType == "OCP3Small" or (.SlotType | type == "string" and test("OCP"))) | .Location.PartLocation.ServiceLabel) //
          empty
        ' 2>/dev/null | head -1)"
        if [[ -n "$OCP_LABEL" && "$OCP_LABEL" != "null" ]]; then
          LOCATION="$OCP_LABEL"
        fi
      fi
    fi
    # --- Ports: NDF, NetworkPorts, HPE PhysicalPorts, or single MAC ---
    NDF_URI="$(echo "$ADAPTER" | jq -r '.NetworkDeviceFunctions["@odata.id"] // empty')"
    NP_URI="$(echo "$ADAPTER" | jq -r '.NetworkPorts["@odata.id"] // empty')"
    # Standard NetworkAdapter can have Ports collection (e.g. /Chassis/1/NetworkAdapters/DA000000/Ports)
    PORTS_URI="$(echo "$ADAPTER" | jq -r '.Ports["@odata.id"] // empty')"
    # Controllers[0].Links.Ports[] (HPE) or Links.NetworkPorts[] (Dell)
    CTRL_LINKS_PORTS="$(echo "$ADAPTER" | jq -r '.Controllers[0].Links.Ports[]? | .["@odata.id"] // empty' 2>/dev/null)"
    NP_LINKS="$(echo "$ADAPTER" | jq -r '.Links.NetworkPorts[]? | .["@odata.id"] // empty' 2>/dev/null)"
    PORT_COUNT=0
    PORTS_DETAILS="[]"
    # Prefer NetworkDeviceFunctions when present (matches HPE: one function per port with Ethernet.MACAddress)
    if [[ -n "$NDF_URI" && "$NDF_URI" != "null" ]]; then
      NDF_COLL="$(_redfish_nics_http_get "$NDF_URI")"
      PORT_COUNT="$(echo "$NDF_COLL" | jq -r '.Members | length // 0' 2>/dev/null)"
      while IFS= read -r member_uri; do
        if [[ -z "$member_uri" ]]; then continue; fi
        MEMBER_JSON="$(_redfish_nics_http_get "$member_uri")"
        # NetworkDeviceFunction: MAC in Ethernet.MACAddress or Ethernet.PermanentMACAddress
        MAC="$(echo "$MEMBER_JSON" | jq -r '(.Ethernet.MACAddress // .Ethernet.PermanentMACAddress // "")')"
        LINK="$(echo "$MEMBER_JSON" | jq -r '.Status.State // ""')"
        SPEED=""
        # Optionally follow PhysicalNetworkPortAssignment to Port for LinkStatus and speed
        PORT_REF="$(echo "$MEMBER_JSON" | jq -r '.PhysicalNetworkPortAssignment["@odata.id"] // .AssignablePhysicalNetworkPorts[0]["@odata.id"] // empty')"
        if [[ -n "$PORT_REF" && "$PORT_REF" != "null" ]]; then
          PORT_JSON="$(_redfish_nics_http_get "$PORT_REF")"
          if [[ -z "$LINK" || "$LINK" == "null" ]]; then
            LINK="$(echo "$PORT_JSON" | jq -r '.LinkStatus // ""')"
          fi
          SPEED="$(echo "$PORT_JSON" | jq -r 'if .CurrentSpeedGbps != null then "\(.CurrentSpeedGbps) Gbps" elif .SpeedMbps != null then "\(.SpeedMbps) Mbps" else "" end')"
        fi
        PENTRY=$(jq -n --arg mac "$MAC" --arg link "$LINK" --arg speed "$SPEED" '{mac: $mac, linkStatus: $link, speed: $speed}')
        PORTS_DETAILS="$(echo "$PORTS_DETAILS" | jq --argjson pe "$PENTRY" '. + [$pe]')"
      done <<< "$(echo "$NDF_COLL" | jq -r '.Members[]? | .["@odata.id"] // empty' 2>/dev/null)"
    elif [[ -n "$NP_URI" && "$NP_URI" != "null" ]]; then
      PORTS_COLL="$(_redfish_nics_http_get "$NP_URI")"
      PORT_COUNT="$(echo "$PORTS_COLL" | jq -r '.Members | length // 0' 2>/dev/null)"
      while IFS= read -r port_uri; do
        if [[ -z "$port_uri" ]]; then continue; fi
        PORT_JSON="$(_redfish_nics_http_get "$port_uri")"
        # NetworkPort: MAC in AssociatedNetworkAddresses or MACAddress
        MAC="$(echo "$PORT_JSON" | jq -r '(.AssociatedNetworkAddresses[0] // .MACAddress // "")')"
        LINK="$(echo "$PORT_JSON" | jq -r '.LinkStatus // .LinkStatusReason // ""')"
        SPEED="$(echo "$PORT_JSON" | jq -r 'if .CurrentSpeedGbps != null then "\(.CurrentSpeedGbps) Gbps" elif .SpeedMbps != null then "\(.SpeedMbps) Mbps" else "" end')"
        PENTRY=$(jq -n --arg mac "$MAC" --arg link "$LINK" --arg speed "$SPEED" '{mac: $mac, linkStatus: $link, speed: $speed}')
        PORTS_DETAILS="$(echo "$PORTS_DETAILS" | jq --argjson pe "$PENTRY" '. + [$pe]')"
      done <<< "$(echo "$PORTS_COLL" | jq -r '.Members[]? | .["@odata.id"] // empty' 2>/dev/null)"
    fi
    # Dell and others: Links.NetworkPorts[] array of port URIs (no Members collection)
    if [[ "$PORT_COUNT" -eq 0 && -n "$NP_LINKS" ]]; then
      while IFS= read -r port_uri; do
        if [[ -z "$port_uri" ]]; then continue; fi
        PORT_JSON="$(_redfish_nics_http_get "$port_uri")"
        MAC="$(echo "$PORT_JSON" | jq -r '(.AssociatedNetworkAddresses[0] // .MACAddress // "")')"
        LINK="$(echo "$PORT_JSON" | jq -r '.LinkStatus // .LinkStatusReason // ""')"
        SPEED="$(echo "$PORT_JSON" | jq -r 'if .CurrentSpeedGbps != null then "\(.CurrentSpeedGbps) Gbps" elif .SpeedMbps != null then "\(.SpeedMbps) Mbps" else "" end')"
        PENTRY=$(jq -n --arg mac "$MAC" --arg link "$LINK" --arg speed "$SPEED" '{mac: $mac, linkStatus: $link, speed: $speed}')
        PORTS_DETAILS="$(echo "$PORTS_DETAILS" | jq --argjson pe "$PENTRY" '. + [$pe]')"
        PORT_COUNT=$((PORT_COUNT + 1))
      done <<< "$NP_LINKS"
    fi
    # HPE Oem.Hpe.PhysicalPorts[] first when present (has MacAddress; avoid extra Ports fetch that may lack MAC)
    if [[ "$PORT_COUNT" -eq 0 ]]; then
      HPE_PORTS="$(echo "$ADAPTER" | jq -c '[.Oem.Hpe.PhysicalPorts[]? | {mac: (.MacAddress // ""), linkStatus: (.LinkStatus // .Status.State // ""), speed: (if .SpeedMbps != null and .SpeedMbps != 0 then "\(.SpeedMbps) Mbps" else "" end)}]' 2>/dev/null)"
      if [[ -n "$HPE_PORTS" && "$HPE_PORTS" != "[]" ]]; then
        PORT_COUNT="$(echo "$HPE_PORTS" | jq 'length')"
        PORTS_DETAILS="$HPE_PORTS"
      fi
    fi
    # Standard Ports collection or Controllers[0].Links.Ports[] (e.g. HPE /Chassis/1/NetworkAdapters/DA000000/Ports)
    if [[ "$PORT_COUNT" -eq 0 ]]; then
      PORT_URIS=""
      if [[ -n "$PORTS_URI" && "$PORTS_URI" != "null" ]]; then
        PORTS_COLL="$(_redfish_nics_http_get "$PORTS_URI")"
        PORT_URIS="$(echo "$PORTS_COLL" | jq -r '.Members[]? | .["@odata.id"] // empty' 2>/dev/null)"
      fi
      if [[ -z "$PORT_URIS" && -n "$CTRL_LINKS_PORTS" ]]; then
        PORT_URIS="$CTRL_LINKS_PORTS"
      fi
      if [[ -n "$PORT_URIS" ]]; then
        while IFS= read -r port_uri; do
          if [[ -z "$port_uri" ]]; then continue; fi
          PORT_JSON="$(_redfish_nics_http_get "$port_uri")"
          MAC="$(echo "$PORT_JSON" | jq -r '(.AssociatedNetworkAddresses[0] // .MACAddress // .Oem.Hpe.MacAddress // "")')"
          LINK="$(echo "$PORT_JSON" | jq -r '.LinkStatus // .LinkStatusReason // .Status.State // .Oem.Hpe.LinkStatus // ""')"
          SPEED="$(echo "$PORT_JSON" | jq -r 'if .CurrentSpeedGbps != null then "\(.CurrentSpeedGbps) Gbps" elif .SpeedMbps != null then "\(.SpeedMbps) Mbps" elif .Oem.Hpe.SpeedMbps != null then "\(.Oem.Hpe.SpeedMbps) Mbps" else "" end')"
          PENTRY=$(jq -n --arg mac "$MAC" --arg link "$LINK" --arg speed "$SPEED" '{mac: $mac, linkStatus: $link, speed: $speed}')
          PORTS_DETAILS="$(echo "$PORTS_DETAILS" | jq --argjson pe "$PENTRY" '. + [$pe]')"
          PORT_COUNT=$((PORT_COUNT + 1))
        done <<< "$PORT_URIS"
      fi
    fi
    # Single-port integrated NICs: adapter-level or first controller MAC when NDF/NP not present
    if [[ "$PORT_COUNT" -eq 0 ]]; then
      SINGLE_MAC="$(echo "$ADAPTER" | jq -r '
        .Ethernet.MACAddress // .Ethernet.PermanentMACAddress //
        .Oem.Dell.MACAddress // .Oem.Hpe.MACAddress //
        .Controllers[0].Ethernet.MACAddress // .Controllers[0].Ethernet.PermanentMACAddress //
        .Controllers[0].MACAddress // ""
      ')"
      if [[ -n "$SINGLE_MAC" && "$SINGLE_MAC" != "null" ]]; then
        PORT_COUNT=1
        PENTRY=$(jq -n --arg mac "$SINGLE_MAC" --arg link "" --arg speed "" '{mac: $mac, linkStatus: $link, speed: $speed}')
        PORTS_DETAILS="$(echo "$PORTS_DETAILS" | jq --argjson pe "$PENTRY" '. + [$pe]')"
      fi
    fi
    # Sort ports by MAC so Port 1..N match ascending MAC order (Redfish API order often differs from physical port)
    if [[ "$PORT_COUNT" -gt 0 ]]; then
      PORTS_DETAILS="$(echo "$PORTS_DETAILS" | jq 'sort_by(if (.mac | type == "string") and (.mac | length) > 0 then .mac else "zzzzzz" end)')"
    fi
    ENTRY=$(jq -n \
      --arg model "$MODEL" \
      --arg state "$STATE" \
      --arg health "$HEALTH" \
      --arg location "$LOCATION" \
      --arg pciAddress "$PCI_ADDR" \
      --arg sku "$SKU" \
      --arg fw "$FW" \
      --arg serial "$SERIAL" \
      --arg part "$PART" \
      --arg mfr "$MFR" \
      --arg adapterUri "$adapter_uri" \
      --argjson ports "$PORT_COUNT" \
      --argjson portDetails "$PORTS_DETAILS" \
      '{model: $model, state: $state, health: $health, location: $location, pciAddress: $pciAddress, sku: $sku, firmwareVersion: $fw, numberOfPorts: $ports, serialNumber: $serial, partNumber: $part, manufacturer: $mfr, adapterUri: $adapterUri, ports: $portDetails}')
    NICS_JSON_ARRAY="$(echo "$NICS_JSON_ARRAY" | jq --argjson e "$ENTRY" '. + [$e]')"
  done <<< "$ADAPTER_IDS"
done <<< "$MEMBERS_JSON"

# --- Systems: merge EthernetInterfaces into adapters, optional fallback, and server hardware ---
SYS_COLL="$(_redfish_nics_http_get "/redfish/v1/Systems")"
SYS_ID="$(echo "$SYS_COLL" | jq -r '.Members[0]["@odata.id"] // empty')"
SYS_JSON=""
[[ -n "$SYS_ID" && "$SYS_ID" != "null" ]] && SYS_JSON="$(_redfish_nics_http_get "$SYS_ID")"

# Merge EthernetInterfaces (with Links.NetworkAdapter) into adapters that have 0 ports
if [[ -n "$SYS_ID" && "$SYS_ID" != "null" ]]; then
  EI_REF="$(echo "$SYS_JSON" | jq -r '.EthernetInterfaces["@odata.id"] // empty')"
  if [[ -n "$EI_REF" && "$EI_REF" != "null" ]]; then
    EI_COLL="$(_redfish_nics_http_get "$EI_REF")"
    EI_MEMBERS="$(echo "$EI_COLL" | jq -r '.Members[]? | .["@odata.id"] // empty' 2>/dev/null)"
    # Build adapter_uri -> [ {mac, linkStatus, speed} ] from EthernetInterfaces that have Links.NetworkAdapter
    EI_MAP="{}"
    while IFS= read -r ei_uri; do
      if [[ -z "$ei_uri" ]]; then continue; fi
      EI="$(_redfish_nics_http_get "$ei_uri")"
      NA_LINK="$(echo "$EI" | jq -r '.Links.NetworkAdapter["@odata.id"] // empty')"
      if [[ -z "$NA_LINK" || "$NA_LINK" == "null" ]]; then continue; fi
      MAC="$(echo "$EI" | jq -r '.MACAddress // ""')"
      LINK="$(echo "$EI" | jq -r '.LinkStatus // .Status.State // ""')"
      SPEED_MBPS="$(echo "$EI" | jq -r '.SpeedMbps // empty')"
      SPEED=""
      if [[ -n "$SPEED_MBPS" && "$SPEED_MBPS" != "null" ]]; then
        SPEED="${SPEED_MBPS} Mbps"
      fi
      PENTRY=$(jq -n --arg mac "$MAC" --arg link "$LINK" --arg speed "$SPEED" '{mac: $mac, linkStatus: $link, speed: $speed}')
      EI_MAP="$(echo "$EI_MAP" | jq --arg uri "$NA_LINK" --argjson pe "$PENTRY" '
        if .[$uri] then .[$uri] += [$pe] else .[$uri] = [$pe] end
      ')"
    done <<< "$EI_MEMBERS"
    # For each NIC with 0 ports, if its adapterUri is in EI_MAP, set ports from EI_MAP
    if [[ "$(echo "$EI_MAP" | jq 'keys | length')" -gt 0 ]]; then
      NICS_JSON_ARRAY="$(echo "$NICS_JSON_ARRAY" | jq --argjson eiMap "$EI_MAP" '
        [.[] |
          . as $nic |
          (if $nic.numberOfPorts == 0 and ($nic.adapterUri | . != null and . != "") then $eiMap[$nic.adapterUri] else null end) as $ports |
          if $ports then $nic | .numberOfPorts = ($ports | length) | .ports = $ports else $nic end
        ]
      ')"
    fi
  fi
fi

# --- No NICs fallback: build from Systems/EthernetInterfaces ---
if [[ "$(echo "$NICS_JSON_ARRAY" | jq 'length')" -eq 0 ]] && [[ -n "$SYS_ID" && "$SYS_ID" != "null" ]]; then
  EI_REF="$(echo "$SYS_JSON" | jq -r '.EthernetInterfaces["@odata.id"] // empty')"
  if [[ -n "$EI_REF" && "$EI_REF" != "null" ]]; then
    EI_COLL="$(_redfish_nics_http_get "$EI_REF")"
    EI_MEMBERS="$(echo "$EI_COLL" | jq -r '.Members[]? | .["@odata.id"] // empty' 2>/dev/null)"
    while IFS= read -r ei_uri; do
        if [[ -z "$ei_uri" ]]; then continue; fi
        EI="$(_redfish_nics_http_get "$ei_uri")"
        MODEL="$(echo "$EI" | jq -r '.Name // .Id // "Ethernet Interface"')"
        STATE="$(echo "$EI" | jq -r '.InterfaceEnabled // .Status.State // "Unknown"')"
        HEALTH="$(echo "$EI" | jq -r '.Status.Health // "Unknown"')"
        LOCATION="$(echo "$EI" | jq -r '.Id // "N/A"')"
        MAC="$(echo "$EI" | jq -r '.MACAddress // ""')"
        SPEED="$(echo "$EI" | jq -r '.SpeedMbps // ""')"
        LINK="$(echo "$EI" | jq -r '.LinkStatus // ""')"
        PORTS_DETAILS=$(jq -n --arg mac "$MAC" --arg link "$LINK" --arg speed "$SPEED" '[{mac: $mac, linkStatus: $link, speed: $speed}]')
        ENTRY=$(jq -n \
          --arg model "$MODEL" \
          --arg state "$STATE" \
          --arg health "$HEALTH" \
          --arg location "$LOCATION" \
          --arg mac "$MAC" \
          --argjson portDetails "$PORTS_DETAILS" \
          '{model: $model, state: $state, health: $health, location: $location, pciAddress: "", sku: "", firmwareVersion: "", numberOfPorts: 1, serialNumber: "", partNumber: "", manufacturer: "", ports: $portDetails}')
        NICS_JSON_ARRAY="$(echo "$NICS_JSON_ARRAY" | jq --argjson e "$ENTRY" '. + [$e]')"
    done <<< "$EI_MEMBERS"
  fi
fi

# --- Server/hardware header (System + Chassis) ---
SERVER_HW_JSON="null"
CHASSIS_ID_HW="$(echo "$MEMBERS_JSON" | head -1)"
if [[ -n "$SYS_ID" && "$SYS_ID" != "null" && -n "$SYS_JSON" ]]; then
  CH_JSON_HW="{}"
  [[ -n "$CHASSIS_ID_HW" ]] && CH_JSON_HW="$(_redfish_nics_http_get "$CHASSIS_ID_HW")"
  SERVER_HW_JSON="$(jq -n \
    --arg sm "$(echo "$SYS_JSON" | jq -r '.Manufacturer // ""')" \
    --arg so "$(echo "$SYS_JSON" | jq -r '.Model // ""')" \
    --arg ss "$(echo "$SYS_JSON" | jq -r '.SerialNumber // ""')" \
    --arg sp "$(echo "$SYS_JSON" | jq -r '.PartNumber // ""')" \
    --arg sk "$(echo "$SYS_JSON" | jq -r '.SKU // ""')" \
    --arg sh "$(echo "$SYS_JSON" | jq -r '.HostName // ""')" \
    --arg pw "$(echo "$SYS_JSON" | jq -r '.PowerState // ""')" \
    --arg sb "$(echo "$SYS_JSON" | jq -r '.BiosVersion // ""')" \
    --arg cm "$(echo "$CH_JSON_HW" | jq -r '.Manufacturer // ""')" \
    --arg co "$(echo "$CH_JSON_HW" | jq -r '.Model // ""')" \
    --arg cs "$(echo "$CH_JSON_HW" | jq -r '.SerialNumber // ""')" \
    --arg cp "$(echo "$CH_JSON_HW" | jq -r '.PartNumber // ""')" \
    --arg ct "$(echo "$CH_JSON_HW" | jq -r '.AssetTag // ""')" \
    --arg cy "$(echo "$CH_JSON_HW" | jq -r '.ChassisType // ""')" \
    '{system: {manufacturer: $sm, model: $so, serialNumber: $ss, partNumber: $sp, sku: $sk, hostName: $sh, powerState: $pw, biosVersion: $sb}, chassis: {manufacturer: $cm, model: $co, serialNumber: $cs, partNumber: $cp, assetTag: $ct, chassisType: $cy}}')"
fi

# --- Build output JSON (strip internal adapterUri) ---
NICS_JSON_ARRAY="$(echo "$NICS_JSON_ARRAY" | jq '[.[] | del(.adapterUri)]')"
OUTPUT_JSON_OBJ="$(jq -n --arg base "$BASE_URL" --argjson nics "$NICS_JSON_ARRAY" --argjson server "$SERVER_HW_JSON" '{redfish: {baseUrl: $base}, server: $server, nics: $nics}')"

if [[ -n "$OUT_FILE" ]]; then
  echo "$OUTPUT_JSON_OBJ" > "$OUT_FILE"
fi

if [[ "$OUTPUT_JSON" == true ]]; then
  echo "$OUTPUT_JSON_OBJ"
  exit 0
fi

# --- Card-style view (BMC Network page style) ---
echo ""
echo "  Server / Hardware"
echo "  ================"
if [[ -n "$SERVER_HW_JSON" && "$SERVER_HW_JSON" != "null" ]]; then
  echo "$SERVER_HW_JSON" | jq -r '
    (.system.manufacturer | if . != "" then "Manufacturer:  \(.)" else empty end),
    (.system.model | if . != "" then "Model:         \(.)" else empty end),
    (.system.serialNumber | if . != "" then "Serial Number: \(.)" else empty end),
    (.system.partNumber | if . != "" then "Part Number:  \(.)" else empty end),
    (.system.sku | if . != "" then "SKU:           \(.)" else empty end),
    (.system.hostName | if . != "" then "Host Name:    \(.)" else empty end),
    (.system.powerState | if . != "" then "Power State:  \(.)" else empty end),
    (.system.biosVersion | if . != "" then "BIOS Version: \(.)" else empty end),
    (.chassis.chassisType | if . != "" then "Chassis Type: \(.)" else empty end),
    (.chassis.assetTag | if . != "" then "Asset Tag:    \(.)" else empty end)
  ' 2>/dev/null | while IFS= read -r line; do [[ -n "$line" ]] && echo "  $line"; done
  echo ""
fi
echo "  Network (Host / Hardware)"
echo "  ========================"
echo ""

len="$(echo "$NICS_JSON_ARRAY" | jq 'length')"
if [[ "$len" -eq 0 ]]; then
  echo "bmc-nic-builder: no network adapters found (Chassis/NetworkAdapters had no Members, or script exited early)."
  echo "  No network adapters found."
  echo ""
  exit 0
fi
# Human-readable location suffix (e.g. DE07A000 -> " (OCP/PCIe slot service label)")
_location_desc() {
  local loc="$1"
  [[ -z "$loc" || "$loc" == "null" ]] && return
  case "$loc" in
    DE[0-9A-F][0-9A-F][A-Z][0-9][0-9][0-9]|DE[0-9A-F][0-9A-F][A-Z][0-9][0-9]) echo " (OCP/PCIe slot service label)" ;;
    Integrated\ Ethernet\ NIC\ *) echo " (onboard)" ;;
    *) ;;
  esac
}

# Print one NIC card from NICS_JSON_ARRAY at index $1
_print_nic_card() {
  local i="$1"
  local model state health location pci_addr sku fw ports serial part mfr port_details health_dot port_count p pmac plink pspeed extra
  model="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].model")"
  state="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].state")"
  health="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].health")"
  location="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].location")"
  pci_addr="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].pciAddress // \"\"")"
  sku="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].sku")"
  fw="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].firmwareVersion")"
  ports="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].numberOfPorts")"
  serial="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].serialNumber // \"\"")"
  part="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].partNumber // \"\"")"
  mfr="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].manufacturer // \"\"")"
  port_details="$(echo "$NICS_JSON_ARRAY" | jq -r ".[$i].ports // []")"
  [[ "$health" == "OK" ]] && health_dot="(OK)" || health_dot="(${health:-Unknown})"

  echo "  ┌─────────────────────────────────────────────────────────────────"
  echo "  │  $model"
  echo "  │  State:   $state"
  echo "  │  Health:  $health_dot"
  echo "  │  Location: $location$(_location_desc "$location")"
  if [[ -n "$pci_addr" && "$pci_addr" != "null" ]]; then echo "  │  PCI Address: $pci_addr"; fi
  if [[ -n "$sku" ]]; then echo "  │  SKU:     $sku"; fi
  if [[ -n "$serial" ]]; then echo "  │  Serial Number: $serial"; fi
  if [[ -n "$part" ]]; then echo "  │  Part Number:  $part"; fi
  if [[ -n "$mfr" ]]; then echo "  │  Manufacturer: $mfr"; fi
  echo "  │  Firmware Version: $fw"
  echo "  │  Number Of Ports:  $ports"
  port_count="$(echo "$port_details" | jq 'length' 2>/dev/null)"
  if [[ -n "$port_count" && "$port_count" -gt 0 ]]; then
    for (( p=0; p<port_count; p++ )); do
      pmac="$(echo "$port_details" | jq -r ".[$p].mac // \"\"")"
      plink="$(echo "$port_details" | jq -r ".[$p].linkStatus // \"\"")"
      pspeed="$(echo "$port_details" | jq -r ".[$p].speed // \"\"")"
      [[ -z "$pmac" || "$pmac" == "null" ]] && pmac="—"
      extra=""; [[ -n "$plink" && "$plink" != "null" ]] && extra="${plink}"
      [[ -n "$pspeed" && "$pspeed" != "null" ]] && extra="${extra:+$extra }${pspeed}"
      [[ -n "$extra" ]] && extra="  ($extra)"
      echo "  │  Port $((p+1)): MAC $pmac$extra"
    done
  fi
  echo "  └─────────────────────────────────────────────────────────────────"
  echo ""
}

for (( i=0; i<len; i++ )); do
  _print_nic_card "$i"
done

if [[ -n "$OUT_FILE" ]]; then
  echo "  JSON written to: $OUT_FILE"
  echo ""
fi
