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
  get

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

### root

Check all resources managed by redfish API(ZT):

```shell
# redfish-bash.sh root
{
  "@odata.context": "/redfish/v1/$metadata#ServiceRoot.ServiceRoot",
  "@odata.etag": "\"1710499398\"",
  "@odata.id": "/redfish/v1",
  "@odata.type": "#ServiceRoot.v1_5_2.ServiceRoot",
  "AccountService": {
    "@odata.id": "/redfish/v1/AccountService"
  },
  "CertificateService": {
    "@odata.id": "/redfish/v1/CertificateService"
  },
  "Chassis": {
    "@odata.id": "/redfish/v1/Chassis"
  },
  "CompositionService": {
    "@odata.id": "/redfish/v1/CompositionService"
  },
  "Description": "The service root for all Redfish requests on this host",
  "EventService": {
    "@odata.id": "/redfish/v1/EventService"
  },
  "Id": "RootService",
  "JsonSchemas": {
    "@odata.id": "/redfish/v1/JsonSchemas"
  },
  "Links": {
    "Sessions": {
      "@odata.id": "/redfish/v1/SessionService/Sessions"
    }
  },
  "Managers": {
    "@odata.id": "/redfish/v1/Managers"
  },
  "Name": "Root Service",
  "Oem": {
    "Ami": {
      "@odata.type": "#AMIServiceRoot.v1_0_0.AMIServiceRoot",
      "InventoryDataStatus": {
        "@odata.id": "/redfish/v1/Oem/Ami/InventoryData/Status"
      },
      "RtpVersion": "1.8.a",
      "configurations": {
        "@odata.id": "/redfish/v1/configurations"
      }
    }
  },
  "Product": "AMI Redfish Server",
  "ProtocolFeaturesSupported": {
    "ExcerptQuery": true,
    "ExpandQuery": {
      "ExpandAll": false,
      "Levels": false,
      "Links": false,
      "MaxLevels": 5,
      "NoLinks": false
    },
    "FilterQuery": true,
    "OnlyMemberQuery": true,
    "SelectQuery": true
  },
  "RedfishVersion": "1.8.0",
  "Registries": {
    "@odata.id": "/redfish/v1/Registries"
  },
  "SessionService": {
    "@odata.id": "/redfish/v1/SessionService"
  },
  "Systems": {
    "@odata.id": "/redfish/v1/Systems"
  },
  "Tasks": {
    "@odata.id": "/redfish/v1/TaskService"
  },
  "TelemetryService": {
    "@odata.id": "/redfish/v1/TelemetryService"
  },
  "UUID": "5a544443-4110-0031-3150-d04b30303633",
  "UpdateService": {
    "@odata.id": "/redfish/v1/UpdateService"
  },
  "Vendor": "AMI"
}
```

Get particular services:

```shell
# redfish-bash.sh root Managers,Systems
{
  "Managers": {
    "@odata.id": "/redfish/v1/Managers"
  },
  "Systems": {
    "@odata.id": "/redfish/v1/Systems"
  }
}
```

```
# redfish-bash.sh get /redfish/v1/Managers
{
  "@odata.context": "/redfish/v1/$metadata#ManagerCollection.ManagerCollection",
  "@odata.etag": "\"1710499398\"",
  "@odata.id": "/redfish/v1/Managers",
  "@odata.type": "#ManagerCollection.ManagerCollection",
  "Description": "The collection for Managers",
  "Members": [
    {
      "@odata.id": "/redfish/v1/Managers/Self"
    }
  ],
  "Members@odata.count": 1,
  "Name": "Manager Collection"
}
```

```
#redfish-bash.sh get /redfish/v1/Systems
{
  "@Redfish.CollectionCapabilities": {
    "@odata.type": "#CollectionCapabilities.v1_2_0.CollectionCapabilities",
    "Capabilities": [
      {
        "CapabilitiesObject": {
          "@odata.id": "/redfish/v1/Systems/Capabilities"
        },
        "Links": {
          "RelatedItem": [
            {
              "@odata.id": "/redfish/v1/CompositionService/ResourceZones/1"
            }
          ],
          "TargetCollection": {
            "@odata.id": "/redfish/v1/Systems"
          }
        },
        "UseCase": "ComputerSystemComposition"
      }
    ]
  },
  "@odata.context": "/redfish/v1/$metadata#ComputerSystemCollection.ComputerSystemCollection",
  "@odata.etag": "\"1708975059\"",
  "@odata.id": "/redfish/v1/Systems",
  "@odata.type": "#ComputerSystemCollection.ComputerSystemCollection",
  "Description": "Collection of Computer Systems",
  "Members": [
    {
      "@odata.id": "/redfish/v1/Systems/Self"
    }
  ],
  "Members@odata.count": 1,
  "Name": "Systems Collection"
}
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

BIOS settings on HPE:

```shell
{
  "@Redfish.Settings": {
    "@odata.type": "#Settings.v1_0_0.Settings",
    "ETag": "E9BA1662",
    "Messages": [
      {
        "MessageId": "Base.1.0.Success"
      },
      {
        "MessageArgs": [
          "NvmePort1"
        ],
        "MessageId": "Base.1.0.PropertyUnknown",
        "RelatedProperties": [
          "#/NvmePort1"
        ]
      },
      {
        "MessageArgs": [
          "NvmePort10"
        ],
        "MessageId": "Base.1.0.PropertyUnknown",
        "RelatedProperties": [
          "#/NvmePort10"
        ]
      },
      {
        "MessageArgs": [
          "NvmePort11"
        ],
        "MessageId": "Base.1.0.PropertyUnknown",
        "RelatedProperties": [
          "#/NvmePort11"
        ]
      },
      {
        "MessageArgs": [
          "NvmePort12"
        ],
        "MessageId": "Base.1.0.PropertyUnknown",
        "RelatedProperties": [
          "#/NvmePort12"
        ]
      }
    ],
    "SettingsObject": {
      "@odata.id": "/redfish/v1/systems/1/bios/settings/"
    },
    "Time": "2024-03-15T15:43:53+00:00"
  },
  "@odata.context": "/redfish/v1/$metadata#Bios.Bios",
  "@odata.etag": "W/\"9D2EF994B025595959AECBAC77CFEBA9\"",
  "@odata.id": "/redfish/v1/systems/1/bios/",
  "@odata.type": "#Bios.v1_0_4.Bios",
  "Actions": {
    "#Bios.ChangePassword": {
      "target": "/redfish/v1/systems/1/bios/settings/Actions/Bios.ChangePasswords/"
    },
    "#Bios.ResetBios": {
      "target": "/redfish/v1/systems/1/bios/settings/Actions/Bios.ResetBios/"
    }
  },
  "AttributeRegistry": "BiosAttributeRegistryH10.v1_1_66",
  "Attributes": {
    "AccessControlService": "Enabled",
    "AcpiHpet": "Enabled",
    "AcpiRootBridgePxm": "Enabled",
    "AcpiSlit": "Enabled",
    "AdjSecPrefetch": "Enabled",
    "AdminEmail": "",
    "AdminName": "",
    "AdminOtherInfo": "",
    "AdminPhone": "",
    "AdvCrashDumpMode": "Disabled",
    "AdvancedMemProtection": "Auto",
    "AllowLoginWithIlo": "Disabled",
    "AssetTagProtection": "Unlocked",
    "AutoPowerOn": "RestoreLastState",
    "BootMode": "Uefi",
    "BootOrderPolicy": "RetryIndefinitely",
    "CollabPowerControl": "Disabled",
    "ConsistentDevNaming": "LomsAndSlots",
    "CustomPostMessage": "",
    "DaylightSavingsTime": "DaylightSavingsTimeDisabled",
    "DcuIpPrefetcher": "Enabled",
    "DcuStreamPrefetcher": "Enabled",
    "DeadBlockPredictor": "Disabled",
...
```

Check particular BIOS settings on HPE:

```shell
# redfish-bash.sh bios Attributes.Sriov,Attributes.WorkloadProfile
{
  "Attributes": {
    "Sriov": "Enabled",
    "WorkloadProfile": "vRAN"
  }
}
```

Update BIOS settings to disable SR-IOV:

```shell
# redfish-bash.sh bios Sriov=Disabled
```

Update BIOS settings to enable vRAN workload profile:

```shell
# redfish-bash.sh bios WorkloadProfile=vRAN
```

### power

Check power status:

```
# redfish-bash.sh power
On
```

Power on:

```shell
# redfish-bash.sh power on
204 https://192.168.18.171/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset
```
Power off:

```shell
# redfish-bash.sh power off
204 https://192.168.18.171/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset
```

Power reset:

```shell
# redfish-bash.sh power restart
204 https://192.168.18.171/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset
```

### virtual-media

Check current virtual-media status:

```shell
# redfish-bash.sh virtual-media
{
  "@odata.context": "/redfish/v1/$metadata#VirtualMedia.VirtualMedia",
  "@odata.etag": "W/\"14700DD6\"",
  "@odata.id": "/redfish/v1/Managers/1/VirtualMedia/2",
  "@odata.type": "#VirtualMedia.v1_3_0.VirtualMedia",
  "Id": "2",
  "Actions": {
    "#VirtualMedia.EjectMedia": {
      "target": "/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.EjectMedia"
    },
    "#VirtualMedia.InsertMedia": {
      "target": "/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.InsertMedia"
    }
  },
  "ConnectedVia": "NotConnected",
  "Description": "Virtual Removable Media",
  "Image": "",
  "Inserted": false,
  "MediaTypes": [
    "CD",
    "DVD"
  ],
  "Name": "VirtualMedia",
  "Oem": {
    "Hpe": {
      "@odata.context": "/redfish/v1/$metadata#HpeiLOVirtualMedia.HpeiLOVirtualMedia",
      "@odata.type": "#HpeiLOVirtualMedia.v2_2_0.HpeiLOVirtualMedia",
      "Actions": {
        "#HpeiLOVirtualMedia.EjectVirtualMedia": {
          "target": "/redfish/v1/Managers/1/VirtualMedia/2/Actions/Oem/Hpe/HpeiLOVirtualMedia.EjectVirtualMedia"
        },
        "#HpeiLOVirtualMedia.InsertVirtualMedia": {
          "target": "/redfish/v1/Managers/1/VirtualMedia/2/Actions/Oem/Hpe/HpeiLOVirtualMedia.InsertVirtualMedia"
        }
      },
      "BootOnNextServerReset": false
    }
  },
  "WriteProtected": true
}
```

Mount ISO as a virtual-media:

```shell
# redfish-bash.sh virtual-media insert http://192.168.58.15/iso/sno130.iso
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.InsertMedia
```

Check status again:
```shell
# redfish-bash.sh virtual-media
{
  "@odata.context": "/redfish/v1/$metadata#VirtualMedia.VirtualMedia",
  "@odata.etag": "W/\"091272C1\"",
  "@odata.id": "/redfish/v1/Managers/1/VirtualMedia/2",
  "@odata.type": "#VirtualMedia.v1_3_0.VirtualMedia",
  "Id": "2",
  "Actions": {
    "#VirtualMedia.EjectMedia": {
      "target": "/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.EjectMedia"
    },
    "#VirtualMedia.InsertMedia": {
      "target": "/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.InsertMedia"
    }
  },
  "ConnectedVia": "URI",
  "Description": "Virtual Removable Media",
  "Image": "http://192.168.58.15/iso/sno130.iso",
  "ImageName": "sno130.iso",
  "Inserted": true,
  "MediaTypes": [
    "CD",
    "DVD"
  ],
  "Name": "VirtualMedia",
  "Oem": {
    "Hpe": {
      "@odata.context": "/redfish/v1/$metadata#HpeiLOVirtualMedia.HpeiLOVirtualMedia",
      "@odata.type": "#HpeiLOVirtualMedia.v2_2_0.HpeiLOVirtualMedia",
      "Actions": {
        "#HpeiLOVirtualMedia.EjectVirtualMedia": {
          "target": "/redfish/v1/Managers/1/VirtualMedia/2/Actions/Oem/Hpe/HpeiLOVirtualMedia.EjectVirtualMedia"
        },
        "#HpeiLOVirtualMedia.InsertVirtualMedia": {
          "target": "/redfish/v1/Managers/1/VirtualMedia/2/Actions/Oem/Hpe/HpeiLOVirtualMedia.InsertVirtualMedia"
        }
      },
      "BootOnNextServerReset": false
    }
  },
  "TransferProtocolType": "HTTP",
  "WriteProtected": true
}
```

Eject virtual media:

```shell
# redfish-bash.sh virtual-media eject
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.EjectMedia
```

### eths

Check ethernet devices on the server:

```shell
# redfish-bash.sh eths
{
  "@odata.context": "/redfish/v1/$metadata#EthernetInterface.EthernetInterface",
  "@odata.etag": "W/\"BF82DB05\"",
  "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/1",
  "@odata.type": "#EthernetInterface.v1_4_1.EthernetInterface",
  "Id": "1",
  "FullDuplex": false,
  "IPv4Addresses": [],
  "IPv4StaticAddresses": [],
  "IPv6AddressPolicyTable": [],
  "IPv6Addresses": [],
  "IPv6StaticAddresses": [],
  "IPv6StaticDefaultGateways": [],
  "InterfaceEnabled": null,
  "LinkStatus": null,
  "MACAddress": "b4:96:91:da:5a:ec",
  "Name": "",
  "NameServers": [],
  "SpeedMbps": null,
  "StaticNameServers": [],
  "Status": {
    "Health": null,
    "State": null
  },
  "UefiDevicePath": "PciRoot(0x1)/Pci(0x2,0x0)/Pci(0x0,0x0)"
}
{
  "@odata.context": "/redfish/v1/$metadata#EthernetInterface.EthernetInterface",
  "@odata.etag": "W/\"A646FBCE\"",
  "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/2",
  "@odata.type": "#EthernetInterface.v1_4_1.EthernetInterface",
  "Id": "2",
  "FullDuplex": false,
  "IPv4Addresses": [],
  "IPv4StaticAddresses": [],
  "IPv6AddressPolicyTable": [],
  "IPv6Addresses": [],
  "IPv6StaticAddresses": [],
  "IPv6StaticDefaultGateways": [],
  "InterfaceEnabled": null,
  "LinkStatus": "LinkUp",
  "MACAddress": "b4:96:91:da:5a:ed",
  "Name": "",
  "NameServers": [],
  "SpeedMbps": null,
  "StaticNameServers": [],
  "Status": {
    "Health": "OK",
    "State": "Enabled"
  }
}
{
  "@odata.context": "/redfish/v1/$metadata#EthernetInterface.EthernetInterface",
  "@odata.etag": "W/\"7A316848\"",
  "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/3",
  "@odata.type": "#EthernetInterface.v1_4_1.EthernetInterface",
  "Id": "3",
  "FullDuplex": false,
  "IPv4Addresses": [],
  "IPv4StaticAddresses": [],
  "IPv6AddressPolicyTable": [],
  "IPv6Addresses": [],
  "IPv6StaticAddresses": [],
  "IPv6StaticDefaultGateways": [],
  "InterfaceEnabled": null,
  "LinkStatus": null,
  "MACAddress": "b4:96:91:da:5a:ee",
  "Name": "",
  "NameServers": [],
  "SpeedMbps": null,
  "StaticNameServers": [],
  "Status": {
    "Health": null,
    "State": null
  }
}
{
  "@odata.context": "/redfish/v1/$metadata#EthernetInterface.EthernetInterface",
  "@odata.etag": "W/\"EFF43F05\"",
  "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/4",
  "@odata.type": "#EthernetInterface.v1_4_1.EthernetInterface",
  "Id": "4",
  "FullDuplex": false,
  "IPv4Addresses": [],
  "IPv4StaticAddresses": [],
  "IPv6AddressPolicyTable": [],
  "IPv6Addresses": [],
  "IPv6StaticAddresses": [],
  "IPv6StaticDefaultGateways": [],
  "InterfaceEnabled": null,
  "LinkStatus": "LinkUp",
  "MACAddress": "b4:96:91:da:5a:ef",
  "Name": "",
  "NameServers": [],
  "SpeedMbps": null,
  "StaticNameServers": [],
  "Status": {
    "Health": "OK",
    "State": "Enabled"
  }
}
{
  "@odata.context": "/redfish/v1/$metadata#EthernetInterface.EthernetInterface",
  "@odata.etag": "W/\"3B401441\"",
  "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/5",
  "@odata.type": "#EthernetInterface.v1_4_1.EthernetInterface",
  "Id": "5",
  "FullDuplex": false,
  "IPv4Addresses": [],
  "IPv4StaticAddresses": [],
  "IPv6AddressPolicyTable": [],
  "IPv6Addresses": [],
  "IPv6StaticAddresses": [],
  "IPv6StaticDefaultGateways": [],
  "InterfaceEnabled": null,
  "LinkStatus": null,
  "MACAddress": "b4:96:91:da:57:14",
  "Name": "",
  "NameServers": [],
  "SpeedMbps": null,
  "StaticNameServers": [],
  "Status": {
    "Health": null,
    "State": null
  },
  "UefiDevicePath": "PciRoot(0x1)/Pci(0x4,0x0)/Pci(0x0,0x0)"
}
{
  "@odata.context": "/redfish/v1/$metadata#EthernetInterface.EthernetInterface",
  "@odata.etag": "W/\"EC5BFAF3\"",
  "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/6",
  "@odata.type": "#EthernetInterface.v1_4_1.EthernetInterface",
  "Id": "6",
  "FullDuplex": false,
  "IPv4Addresses": [],
  "IPv4StaticAddresses": [],
  "IPv6AddressPolicyTable": [],
  "IPv6Addresses": [],
  "IPv6StaticAddresses": [],
  "IPv6StaticDefaultGateways": [],
  "InterfaceEnabled": null,
  "LinkStatus": null,
  "MACAddress": "b4:96:91:da:57:15",
  "Name": "",
  "NameServers": [],
  "SpeedMbps": null,
  "StaticNameServers": [],
  "Status": {
    "Health": null,
    "State": null
  }
}
{
  "@odata.context": "/redfish/v1/$metadata#EthernetInterface.EthernetInterface",
  "@odata.etag": "W/\"6C88DF7D\"",
  "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/7",
  "@odata.type": "#EthernetInterface.v1_4_1.EthernetInterface",
  "Id": "7",
  "FullDuplex": false,
  "IPv4Addresses": [],
  "IPv4StaticAddresses": [],
  "IPv6AddressPolicyTable": [],
  "IPv6Addresses": [],
  "IPv6StaticAddresses": [],
  "IPv6StaticDefaultGateways": [],
  "InterfaceEnabled": null,
  "LinkStatus": null,
  "MACAddress": "b4:96:91:da:57:16",
  "Name": "",
  "NameServers": [],
  "SpeedMbps": null,
  "StaticNameServers": [],
  "Status": {
    "Health": null,
    "State": null
  }
}
{
  "@odata.context": "/redfish/v1/$metadata#EthernetInterface.EthernetInterface",
  "@odata.etag": "W/\"A5E93E38\"",
  "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/8",
  "@odata.type": "#EthernetInterface.v1_4_1.EthernetInterface",
  "Id": "8",
  "FullDuplex": false,
  "IPv4Addresses": [],
  "IPv4StaticAddresses": [],
  "IPv6AddressPolicyTable": [],
  "IPv6Addresses": [],
  "IPv6StaticAddresses": [],
  "IPv6StaticDefaultGateways": [],
  "InterfaceEnabled": null,
  "LinkStatus": null,
  "MACAddress": "b4:96:91:da:57:17",
  "Name": "",
  "NameServers": [],
  "SpeedMbps": null,
  "StaticNameServers": [],
  "Status": {
    "Health": null,
    "State": null
  }
}
{
  "@odata.context": "/redfish/v1/$metadata#EthernetInterface.EthernetInterface",
  "@odata.etag": "W/\"0920FBB0\"",
  "@odata.id": "/redfish/v1/Systems/1/EthernetInterfaces/9",
  "@odata.type": "#EthernetInterface.v1_4_1.EthernetInterface",
  "Id": "9",
  "FullDuplex": false,
  "IPv4Addresses": [],
  "IPv4StaticAddresses": [],
  "IPv6AddressPolicyTable": [],
  "IPv6Addresses": [],
  "IPv6StaticAddresses": [],
  "IPv6StaticDefaultGateways": [],
  "InterfaceEnabled": null,
  "LinkStatus": null,
  "MACAddress": "5c:ba:2c:1f:6e:97",
  "Name": "",
  "NameServers": [],
  "SpeedMbps": null,
  "StaticNameServers": [],
  "Status": {
    "Health": null,
    "State": null
  },
  "UefiDevicePath": "PciRoot(0x0)/Pci(0x1C,0x5)/Pci(0x0,0x0)"
}
```

### secure-boot

Check if secure boot is enabled on the node:

```shell
# redfish-bash.sh secure-boot
false
```

Enable secure-boot:
```shell
# redfish-bash.sh secure-boot true
{"@Message.ExtendedInfo":[{"Message":"The request completed successfully.","MessageArgs":[],"MessageArgs@odata.count":0,"MessageId":"Base.1.12.Success","RelatedProperties":[],"RelatedProperties@odata.count":0,"Resolution":"None","Severity":"OK"},{"Message":"The operation is successfully completed.","MessageArgs":[],"MessageArgs@odata.count":0,"MessageId":"IDRAC.2.9.SYS430","RelatedProperties":[],"RelatedProperties@odata.count":0,"Resolution":"No response action is required.However, to make them immediately effective, restart the host server.","Severity":"Informational"}]}secure boot has been set as true, you may need to reboot the node to take effect.
```

Disable secure-boot:
```shell
# redfish-bash.sh secure-boot false
{"error":{"@Message.ExtendedInfo":[{"Message":"Unable to apply the configuration changes because an import or export operation is currently in progress.","MessageArgs":["SecureBootEnable"],"MessageArgs@odata.count":1,"MessageId":"IDRAC.2.9.SYS431","RelatedProperties":["#/SecureBootEnable"],"RelatedProperties@odata.count":1,"Resolution":"Wait for the current import or export operation to complete and retry the operation. If the issue persists, contact your service provider.","Severity":"Warning"},{"Message":"Unable to complete the operation because the provider is not ready.","MessageArgs":[],"MessageArgs@odata.count":0,"MessageId":"IDRAC.2.9.RAC0508","RelatedProperties":[],"RelatedProperties@odata.count":0,"Resolution":"Wait for few minutes, refresh the page and retry. If the problem persists, reset the iDRAC and retry the operation.","Severity":"Critical"}],"code":"Base.1.12.GeneralError","message":"A general error has occurred. See ExtendedInfo for more information"}}secure boot has been set as false, you may need to reboot the node to take effect.
```

### storage

Check storages:

```shell
# redfish-bash.sh storage
{
  "@odata.context": "/redfish/v1/$metadata#StorageCollection.StorageCollection",
  "@odata.etag": "W/\"570254F2\"",
  "@odata.id": "/redfish/v1/Systems/1/Storage",
  "@odata.type": "#StorageCollection.StorageCollection",
  "Description": "Storage subsystems known to this system",
  "Name": "Storage",
  "Members": [
    {
      "@odata.id": "/redfish/v1/Systems/1/Storage/DA000000"
    },
    {
      "@odata.id": "/redfish/v1/Systems/1/Storage/DA000001"
    }
  ],
  "Members@odata.count": 2
}
```

Check particular storage:

```shell
# redfish-bash.sh storage DA000000
{
  "@odata.context": "/redfish/v1/$metadata#Storage.Storage",
  "@odata.etag": "W/\"836C2E84\"",
  "@odata.id": "/redfish/v1/Systems/1/Storage/DA000000",
  "@odata.type": "#Storage.v1_12_0.Storage",
  "Id": "DA000000",
  "Controllers": {
    "@odata.id": "/redfish/v1/Systems/1/Storage/DA000000/Controllers"
  },
  "Drives": [
    {
      "@odata.id": "/redfish/v1/Systems/1/Storage/DA000000/Drives/DA000000/"
    }
  ],
  "Links": {
    "Enclosures": [
      {
        "@odata.id": "/redfish/v1/Chassis/1"
      }
    ]
  },
  "Name": "NVMe Storage System",
  "Status": {
    "Health": "OK",
    "State": "Enabled"
  },
  "StorageControllers": [
    {
      "@odata.id": "/redfish/v1/Systems/1/Storage/DA000000#/StorageControllers/0/",
      "FirmwareVersion": "EDA7602Q",
      "Identifiers": [],
      "Location": {
        "PartLocation": {
          "LocationOrdinalValue": 10,
          "LocationType": "Slot",
          "ServiceLabel": "Slot 10"
        }
      },
      "MemberId": "0",
      "Model": "SAMSUNG MZ1LB1T9HALS-00007",
      "Name": "NVMe Storage Controller",
      "SerialNumber": "S436NA0R757299",
      "Status": {
        "Health": "OK",
        "State": "Enabled"
      },
      "SupportedControllerProtocols": [
        "PCIe"
      ],
      "SupportedDeviceProtocols": [
        "NVMe"
      ]
    }
  ]
}
```

### get

If any command above cannot satisfy your needs, you can use command 'get' to fetch the information:

```shell
# ./redfish-bash.sh get
{
  "@odata.context": "/redfish/v1/$metadata#ServiceRoot.ServiceRoot",
  "@odata.etag": "\"1710499398\"",
  "@odata.id": "/redfish/v1",
  "@odata.type": "#ServiceRoot.v1_5_2.ServiceRoot",
  "AccountService": {
    "@odata.id": "/redfish/v1/AccountService"
  },
  "CertificateService": {
    "@odata.id": "/redfish/v1/CertificateService"
  },
  "Chassis": {
    "@odata.id": "/redfish/v1/Chassis"
  },
  "CompositionService": {
    "@odata.id": "/redfish/v1/CompositionService"
  },
  "Description": "The service root for all Redfish requests on this host",
  "EventService": {
    "@odata.id": "/redfish/v1/EventService"
  },
  "Id": "RootService",
  "JsonSchemas": {
    "@odata.id": "/redfish/v1/JsonSchemas"
  },
  "Links": {
    "Sessions": {
      "@odata.id": "/redfish/v1/SessionService/Sessions"
    }
  },
  "Managers": {
    "@odata.id": "/redfish/v1/Managers"
  },
  "Name": "Root Service",
  "Oem": {
    "Ami": {
      "@odata.type": "#AMIServiceRoot.v1_0_0.AMIServiceRoot",
      "InventoryDataStatus": {
        "@odata.id": "/redfish/v1/Oem/Ami/InventoryData/Status"
      },
      "RtpVersion": "1.8.a",
      "configurations": {
        "@odata.id": "/redfish/v1/configurations"
      }
    }
  },
  "Product": "AMI Redfish Server",
  "ProtocolFeaturesSupported": {
    "ExcerptQuery": true,
    "ExpandQuery": {
      "ExpandAll": false,
      "Levels": false,
      "Links": false,
      "MaxLevels": 5,
      "NoLinks": false
    },
    "FilterQuery": true,
    "OnlyMemberQuery": true,
    "SelectQuery": true
  },
  "RedfishVersion": "1.8.0",
  "Registries": {
    "@odata.id": "/redfish/v1/Registries"
  },
  "SessionService": {
    "@odata.id": "/redfish/v1/SessionService"
  },
  "Systems": {
    "@odata.id": "/redfish/v1/Systems"
  },
  "Tasks": {
    "@odata.id": "/redfish/v1/TaskService"
  },
  "TelemetryService": {
    "@odata.id": "/redfish/v1/TelemetryService"
  },
  "UUID": "5a544443-4110-0031-3150-d04b30303633",
  "UpdateService": {
    "@odata.id": "/redfish/v1/UpdateService"
  },
  "Vendor": "AMI"
}
```

```shell
# redfish-bash.sh get /redfish/v1/TelemetryService
{
  "@odata.context": "/redfish/v1/$metadata#TelemetryService.TelemetryService",
  "@odata.etag": "\"1710499398\"",
  "@odata.id": "/redfish/v1/TelemetryService",
  "@odata.type": "#TelemetryService.v1_2_1.TelemetryService",
  "Actions": {
    "#TelemetryService.SubmitTestMetricReport": {
      "@Redfish.ActionInfo": "/redfish/v1/TelemetryService/SubmitTestMetricReportActionInfo",
      "target": "/redfish/v1/TelemetryService/Actions/TelemetryService.SubmitTestMetricReport"
    }
  },
  "Description": "TelemetryService",
  "Id": "TelemetryService",
  "LogService": {
    "@odata.id": "/redfish/v1/TelemetryService/LogService"
  },
  "MaxReports": 5,
  "MetricDefinitions": {
    "@odata.id": "/redfish/v1/TelemetryService/MetricDefinitions"
  },
  "MetricReportDefinitions": {
    "@odata.id": "/redfish/v1/TelemetryService/MetricReportDefinitions"
  },
  "MetricReports": {
    "@odata.id": "/redfish/v1/TelemetryService/MetricReports"
  },
  "MinCollectionInterval": "PT5S",
  "Name": "TelemetryService",
  "ServiceEnabled": true,
  "Status": {
    "Health": "OK",
    "State": "Enabled"
  },
  "SupportedCollectionFunctions": [
    "Average",
    "Maximum",
    "Summation",
    "Minimum"
  ],
  "SupportedCollectionFunctions@Redfish.AllowableValues": [
    "Average",
    "Maximum",
    "Summation",
    "Minimum"
  ],
  "Triggers": {
    "@odata.id": "/redfish/v1/TelemetryService/Triggers"
  }
}
```


## How to extend?

Check if you can do with the existing command(s), If yes maybe add a new example in the instruction. If Not, 
based on what function you are going to add, consider which command name you are going to use, define the function in the script like below:

your_command_name(){
  logic here
}

Then add usage or example in function usage(), that is it, then you can test it on your target server(s).

