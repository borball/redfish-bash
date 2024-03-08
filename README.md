# redfish-bash

A wrapper script of redfish API, tested on ZT/HPE/Dell/Sushy-tools servers.

## Install

- Note: Install yq with instruction: https://github.com/mikefarah/yq?tab=readme-ov-file#install

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
Usage :   redfish-bash.sh command
Example : redfish-bash.sh login https://192.168.13.146 Administrator:superuser
Example : redfish-bash.sh login https://192.168.58.15:8080 a:b 22222222-1111-1111-0000-000000000010
Example : redfish-bash.sh servers
Example : redfish-bash.sh server
Example : redfish-bash.sh server 1
Example : redfish-bash.sh managers
Example : redfish-bash.sh bios '.Attributes.WorkloadProfile'
Run : redfish-bash.sh login or redfish-bash.sh server before using other commands.
Available commands : 
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
  systems
  manager
  managers
  #BMC reset
  reset
  bios
  bios-attr k v
  eths
  power
  power on|off|restart
  virtual-media
  virtual-media insert http://192.168.58.15/iso/agent-130.iso
  virtual-media eject
  boot-once-from-cd
  secure-boot
  secure-boot true|false
  storage

```

## Examples

```shell
## login
# redfish-bash.sh login https://192.168.13.146 Administrator:superuser
login successful, will use this server for the following commands.
index: 0
bmc: https://192.168.13.145
userPass: Administrator:superuser

## login to the BMC console simulated by sushy-tools:
# redfish-bash.sh login https://192.168.58.15:8080 a:b 22222222-1111-1111-0000-000000000010
login successful, will use this server for the following commands.
index: 2
bmc: https://192.168.58.15:8080
userPass: dummy:dummy

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

# server
# redfish-bash.sh server 
following server is being used:

# redfish-bash.sh server 1
following server will be used:
index: 1
bmc: https://192.168.13.146
userPass: Administrator:superuser

# redfish-bash.sh server 
following server is being used:
index: 1
bmc: https://192.168.13.146
userPass: Administrator:superuser

## ZT
# redfish-bash.sh manager
https://192.168.13.146/redfish/v1/Managers/Self
## HPE
# redfish-bash.sh  manager
https://192.168.14.130/redfish/v1/Managers/1
## Dell
$ redfish-bash.sh manager
https://192.168.18.162/redfish/v1/Managers/iDRAC.Embedded.1

## ZT
# redfish-bash.sh system
https://192.168.13.146/redfish/v1/Systems/Self
## HPE
# redfish-bash.sh system
https://192.168.14.130/redfish/v1/Systems/1
## Dell
$ redfish-bash.sh system
https://192.168.18.162/redfish/v1/Systems/System.Embedded.1

# redfish-bash.sh eths
{
  "Id": "EthernetInterface0",
  "MACAddress": "B4:96:91:B4:8A:E8",
  "LinkStatus": "LinkUp",
  "Status": {
    "Health": "OK",
    "State": "Enabled"
  }
}
{
  "Id": "EthernetInterface1",
  "MACAddress": "B4:96:91:B4:8A:E9",
  "LinkStatus": "LinkUp",
  "Status": {
    "Health": "OK",
    "State": "Enabled"
  }
}
{
  "Id": "EthernetInterface2",
  "MACAddress": "B4:96:91:B4:8A:EA",
  "LinkStatus": "LinkDown",
  "Status": {
    "Health": "OK",
    "State": "Disabled"
  }
}
{
  "Id": "EthernetInterface3",
  "MACAddress": "B4:96:91:B4:8A:EB",
  "LinkStatus": "LinkDown",
  "Status": {
    "Health": "OK",
    "State": "Disabled"
  }
}
{
  "Id": "EthernetInterface4",
  "MACAddress": "B4:96:91:B4:86:C4",
  "LinkStatus": "LinkUp",
  "Status": {
    "Health": "OK",
    "State": "Enabled"
  }
}
{
  "Id": "EthernetInterface5",
  "MACAddress": "B4:96:91:B4:86:C5",
  "LinkStatus": "LinkUp",
  "Status": {
    "Health": "OK",
    "State": "Enabled"
  }
}
{
  "Id": "EthernetInterface6",
  "MACAddress": "B4:96:91:B4:86:C6",
  "LinkStatus": "LinkDown",
  "Status": {
    "Health": "OK",
    "State": "Disabled"
  }
}
{
  "Id": "EthernetInterface7",
  "MACAddress": "B4:96:91:B4:86:C7",
  "LinkStatus": "LinkDown",
  "Status": {
    "Health": "OK",
    "State": "Disabled"
  }
}
{
  "Id": "VirtualEthernetInterface8",
  "MACAddress": "AE:CD:C9:44:5C:35",
  "LinkStatus": "LinkUp",
  "Status": {
    "Health": "OK",
    "State": "Enabled"
  }
}

# redfish-bash.sh bios ".Attributes.WorkloadProfile"
vRAN

# redfish-bash.sh bios-attr EnergyPerformancePreference Enabled
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"iLO.2.14.SystemResetRequired"}]}}200 https://192.168.14.132/redfish/v1/systems/1/bios/settings/

# redfish-bash.sh managers '.VirtualMedia."@odata.id"'
/redfish/v1/Managers/1/VirtualMedia


# redfish-bash.sh power
On

# redfish-bash.sh power abc
abc is not valid command.

# redfish-bash.sh power on
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageArgs":["Power is on"],"MessageId":"iLO.2.16.InvalidOperationForSystemState"}]}}400 https://192.168.14.130/redfish/v1/Systems/1/Actions/ComputerSystem.Reset

# redfish-bash.sh power off
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Systems/1/Actions/ComputerSystem.Reset

# redfish-bash.sh power restart
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Systems/1/Actions/ComputerSystem.Reset


# redfish-bash.sh virtual-media insert http://192.168.58.15/iso/agent-130.iso
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.InsertMedia


# redfish-bash.sh virtual-media 
{
  "@odata.context": "/redfish/v1/$metadata#VirtualMedia.VirtualMedia",
  "@odata.etag": "W/\"0D292F2F\"",
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
  "Image": "http://192.168.58.15/iso/agent-130.iso",
  "ImageName": "agent-130.iso",
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

# redfish-bash.sh virtual-media eject
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.EjectMedia

## check current secure-boot setting
$ redfish-bash.sh secure-boot 
false

## disable secure-boot
$ redfish-bash.sh secure-boot false
secure boot has been set as false, you may need to reboot the node to take effect.

## list storage
$ redfish-bash.sh storage
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

## list storage
$ redfish-bash.sh storage DA000000
redfish-bash.sh storage DA000000
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