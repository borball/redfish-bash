# redfish-bash

A wrapper script of redfish API, tested on ZT/HPE/Dell/Sushy-tools servers.

## Install

- Note: Install yq with instruction: https://github.com/mikefarah/yq?tab=readme-ov-file#install
- Note: Install jq(1.7+) with instruction: https://github.com/jqlang/jq?tab=readme-ov-file#installation

```shell
curl -fsSL -o /usr/local/bin/redfish-bash.sh https://raw.githubusercontent.com/borball/redfish-bash/master/redfish-bash.sh
chmod +x /usr/local/bin/redfish-bash.sh
```

## Usage

```shell
redfish-bash.sh
```

```shell
# redfish-bash.sh 
Usage :   ./redfish-bash.sh command <parameters>
Available commands:
  -------------------------------------------
  #login BMC
  login [bmc] [username:password]
  login [bmc] [username:password] [kvm_uuid]
  -------------------------------------------
  #bmc server context
  #all servers:
  servers
  #current server
  server
  #use server N
  server N
  -------------------------------------------
  #resource management
  system
  system <jsonpath>
  manager
  manager <jsonpath>
  #BMC reboot
  bmc-reboot
  bios
  #read attributes
  bios <jsonpath>
  #modify attribute
  bios <attribute=value>
  eths
  power
  power on|off|restart
  virtual-media
  virtual-media insert <url>>
  virtual-media eject
  boot-once-from-cd
  secure-boot
  secure-boot true|false
  storage
  storage <ID>

Examples:
  ./redfish-bash.sh login https://192.168.13.146 Administrator:superuser
  ./redfish-bash.sh login https://192.168.13.146 Administrator:superuser [kvm_uuid]
  ./redfish-bash.sh servers
  ./redfish-bash.sh server
  ./redfish-bash.sh server 0
  ./redfish-bash.sh system
  ./redfish-bash.sh system Manufacturer,Model
  ./redfish-bash.sh bios
  ./redfish-bash.sh bios Attributes.WorkloadProfile
  ./redfish-bash.sh bios WorkloadProfile=vRAN
  ./redfish-bash.sh eths
  ./redfish-bash.sh power
  ./redfish-bash.sh power on|off|restart
  ./redfish-bash.sh virtual-media
  ./redfish-bash.sh virtual-media insert http://192.168.58.15/iso/agent-130.iso
  ./redfish-bash.sh virtual-media eject
  ./redfish-bash.sh boot-once-from-cd
  ./redfish-bash.sh secure-boot
  ./redfish-bash.sh secure-boot true|false
  ./redfish-bash.sh storage
  ./redfish-bash.sh storage DA000000
Run : ./redfish-bash.sh login before using other commands for the first time.

```

## Examples

### login

```shell
## login
# redfish-bash.sh login https://192.168.13.146 Administrator:superuser
login successful, will use this server for the following commands.
index: 0
bmc: https://192.168.13.146
userPass: Administrator:superuser

## login to the BMC console simulated by sushy-tools:
# redfish-bash.sh login https://192.168.58.15:8080 a:b 22222222-1111-1111-0000-000000000010
login successful, will use this server for the following commands.
index: 2
bmc: https://192.168.58.15:8080
userPass: dummy:dummy
```

### servers
Check all servers managed by redfish-bash:

```
## servers
# redfish-bash.sh servers
following server is being used:


All servers in the list:
0   https://192.168.58.15:8080
1   https://192.168.13.146
2   https://192.168.13.147
3   https://192.168.13.148
4   https://192.168.13.149
5   https://192.168.14.130
6   https://192.168.14.131
7   https://192.168.14.132
8   https://192.168.14.133
use command 'server' to check the current server
use command 'server N' to switch the servers

```
Check current server managed by redfish-bash:
```
# server
# redfish-bash.sh server 
following server is being used:

```
Switch to other server:
```
# redfish-bash.sh server 1
following server will be used:
index: 1
bmc: https://192.168.13.146
userPass: Administrator:superuser
```

### manager

Check all manager information on ZT:
```
## ZT
# redfish-bash.sh manager
{
  "@Redfish.Settings": {
    "@odata.type": "#Settings.v1_2_2.Settings",
    "SettingsObject": {
      "@odata.id": "/redfish/v1/Systems/Self/Bios/SD"
    }
  },
  "@odata.context": "/redfish/v1/$metadata#Bios.Bios",
  "@odata.etag": "\"1708975059\"",
  "@odata.id": "/redfish/v1/Systems/Self/Bios",
  "@odata.type": "#Bios.v1_1_0.Bios",
  "Actions": {
    "#Bios.ChangePassword": {
      "@Redfish.ActionInfo": "/redfish/v1/Systems/Self/Bios/ChangePasswordActionInfo",
      "target": "/redfish/v1/Systems/Self/Bios/Actions/Bios.ChangePassword"
    },
    "#Bios.ResetBios": {
      "@Redfish.ActionInfo": "/redfish/v1/Systems/Self/Bios/ResetBiosActionInfo",
      "target": "/redfish/v1/Systems/Self/Bios/Actions/Bios.ResetBios"
    },
    "#ZtVga.ChangeState": {
      "@Redfish.ActionInfo": "/redfish/v1/Systems/Self/Bios/ChangeStateActionInfo",
      "target": "/redfish/v1/Systems/Self/Bios/Actions/ZtVga.ChangeState"
    }
  },
...
```

Check particular manager attributes on ZT:

```shell
# redfish-bash.sh manager FirmwareVersion,PowerState,ManagerType
{
  "FirmwareVersion": "0.43.00",
  "PowerState": "On",
  "ManagerType": "BMC"
}
```
Check all manager information on HPE:
```
## HPE
# redfish-bash.sh  manager
{
  "@odata.context": "/redfish/v1/$metadata#Manager.Manager",
  "@odata.etag": "W/\"5DF7965A\"",
  "@odata.id": "/redfish/v1/Managers/1",
  "@odata.type": "#Manager.v1_5_1.Manager",
  "Id": "1",
  "Actions": {
    "#Manager.Reset": {
      "ResetType@Redfish.AllowableValues": [
        "ForceRestart",
        "GracefulRestart"
      ],
      "target": "/redfish/v1/Managers/1/Actions/Manager.Reset"
    }
  },
  "CommandShell": {
    "ConnectTypesSupported": [
      "SSH",
      "Oem"
    ],
    "MaxConcurrentSessions": 9,
    "ServiceEnabled": true
  },
  "DateTime": "2024-03-15T17:27:53Z",
  "DateTimeLocalOffset": "+00:00",
  "EthernetInterfaces": {
    "@odata.id": "/redfish/v1/Managers/1/EthernetInterfaces"
  },
  "FirmwareVersion": "iLO 5 v2.81",
...
```

Check particular manager attributes on HPE:
```shell
# redfish-bash.sh manager FirmwareVersion,PowerState,ManagerType
{
  "FirmwareVersion": "iLO 5 v2.81",
  "PowerState": null,
  "ManagerType": "BMC"
}
```

Check all manager information on Dell:

```shell
## Dell
$ redfish-bash.sh manager
{
  "@odata.context": "/redfish/v1/$metadata#Manager.Manager",
  "@odata.id": "/redfish/v1/Managers/iDRAC.Embedded.1",
  "@odata.type": "#Manager.v1_17_0.Manager",
  "Actions": {
    "#Manager.Reset": {
      "ResetType@Redfish.AllowableValues": [
        "GracefulRestart"
      ],
      "target": "/redfish/v1/Managers/iDRAC.Embedded.1/Actions/Manager.Reset"
    },
    "#Manager.ResetToDefaults": {
      "ResetType@Redfish.AllowableValues": [
        "ResetAll",
        "PreserveNetworkAndUsers"
      ],
      "target": "/redfish/v1/Managers/iDRAC.Embedded.1/Actions/Manager.ResetToDefaults"
    },
...
```

Check particular manager attributes on Dell:
```shell
# redfish-bash.sh manager FirmwareVersion,PowerState,ManagerType
{
  "FirmwareVersion": "7.00.30.00",
  "PowerState": "On",
  "ManagerType": "BMC"
}

```

### system

Check all system information on ZT:

```
## ZT
# redfish-bash.sh system
{
  "@Redfish.Settings": {
    "@odata.type": "#Settings.v1_2_2.Settings",
    "SettingsObject": {
      "@odata.id": "/redfish/v1/Systems/Self/SD"
    }
  },
  "@odata.context": "/redfish/v1/$metadata#ComputerSystem.ComputerSystem",
  "@odata.etag": "\"1708975059\"",
  "@odata.id": "/redfish/v1/Systems/Self",
  "@odata.type": "#ComputerSystem.v1_8_0.ComputerSystem",
  "Actions": {
    "#ComputerSystem.Reset": {
      "@Redfish.ActionInfo": "/redfish/v1/Systems/Self/ResetActionInfo",
      "@Redfish.OperationApplyTimeSupport": {
        "@odata.type": "#Settings.v1_2_2.OperationApplyTimeSupport",
        "MaintenanceWindowDurationInSeconds": 600,
        "MaintenanceWindowResource": {
          "@odata.id": "/redfish/v1/Systems/Self"
        },
        "SupportedValues": [
          "Immediate",
          "AtMaintenanceWindowStart"
        ]
      },
      "ResetType@Redfish.AllowableValues": [
        "Nmi",
        "On",
        "ForceRestart",
        "ForceOff",
        "GracefulShutdown"
      ],
      "target": "/redfish/v1/Systems/Self/Actions/ComputerSystem.Reset"
    }
  },
...
```

Check particular system attributes on ZT:
```shell
{
"SystemType": "Physical",
"Name": "Proteus I_Mix",
"Manufacturer": "ZTSYSTEMS"
}
```

Check all system information on HPE:
```
## HPE
# redfish-bash.sh system
{
  "@odata.context": "/redfish/v1/$metadata#ComputerSystem.ComputerSystem",
  "@odata.etag": "W/\"98A3D2D0\"",
  "@odata.id": "/redfish/v1/Systems/1",
  "@odata.type": "#ComputerSystem.v1_13_0.ComputerSystem",
  "Id": "1",
  "Actions": {
    "#ComputerSystem.Reset": {
      "ResetType@Redfish.AllowableValues": [
        "On",
        "ForceOff",
        "GracefulShutdown",
        "ForceRestart",
        "Nmi",
        "PushPowerButton",
        "GracefulRestart"
      ],
      "target": "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset"
    }
  },
...

```

Check particular system attributes on HPE:
```shell
# redfish-bash.sh system SystemType,Name,Manufacturer
{
  "SystemType": "Physical",
  "Name": "Computer System",
  "Manufacturer": "HPE"
}
```

Check all system information on Dell:
```
## Dell
# redfish-bash.sh system
{
  "@Redfish.Settings": {
    "@odata.context": "/redfish/v1/$metadata#Settings.Settings",
    "@odata.type": "#Settings.v1_3_5.Settings",
    "SettingsObject": {
      "@odata.id": "/redfish/v1/Systems/System.Embedded.1/Settings"
    },
    "SupportedApplyTimes": [
      "OnReset"
    ]
  },
  "@odata.context": "/redfish/v1/$metadata#ComputerSystem.ComputerSystem",
  "@odata.id": "/redfish/v1/Systems/System.Embedded.1",
  "@odata.type": "#ComputerSystem.v1_20_0.ComputerSystem",
  "Actions": {
    "#ComputerSystem.Reset": {
      "target": "/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset",
      "ResetType@Redfish.AllowableValues": [
        "On",
        "ForceOff",
        "ForceRestart",
        "GracefulRestart",
        "GracefulShutdown",
        "PushPowerButton",
        "Nmi",
        "PowerCycle"
      ]
    }
  }
...

```

Check particular system attributes on Dell:
```shell
{
  "SystemType": "Physical",
  "Name": "System",
  "Manufacturer": "Dell Inc."
}
```

### bios

### power

### virtual-media

### eths

### secure-boot

### storage