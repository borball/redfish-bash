# redfish-bash

## Usage

```shell
./redfish-bash.sh
```

```shell
# ./redfish-bash.sh 
Usage :   ./redfish-bash.sh command
Example : ./redfish-bash.sh login https://192.168.13.146 Administrator:superuser
Example : ./redfish-bash.sh managers
Example : ./redfish-bash.sh bios '.Attributes.WorkloadProfile'
Run : ./redfish-bash.sh login before using other commands
Available commands : 
  login [bmc] [username:password]
  system
  systems
  manager
  managers
  bios
  eths
  power
  power on|off|restart
  virtual-media
  virtual-media insert http://192.168.58.15/iso/agent-130.iso
  virtual-media eject

```

## Examples

```shell
## login
# ./redfish-bash.sh login https://192.168.13.146 Administrator:superuser
login succeed, will use /root/.bmc.cfg next time.

## ZT
# ./redfish-bash.sh manager
https://192.168.13.146/redfish/v1/Managers/Self
## HPE
# ./redfish-bash.sh  manager
https://192.168.14.130/redfish/v1/Managers/1

## ZT
# ./redfish-bash.sh system
https://192.168.13.146/redfish/v1/Systems/Self
## HPE
# ./redfish-bash.sh system
https://192.168.14.130/redfish/v1/Systems/1

# ./redfish-bash.sh eths
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

# ./redfish-bash.sh bios ".Attributes.WorkloadProfile"
vRAN

# ./redfish-bash.sh managers '.VirtualMedia."@odata.id"'
/redfish/v1/Managers/1/VirtualMedia


# ./redfish-bash.sh power
On

# ./redfish-bash.sh power abc
abc is not valid command.

# ./redfish-bash.sh power on
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageArgs":["Power is on"],"MessageId":"iLO.2.16.InvalidOperationForSystemState"}]}}400 https://192.168.14.130/redfish/v1/Systems/1/Actions/ComputerSystem.Reset

# ./redfish-bash.sh power off
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Systems/1/Actions/ComputerSystem.Reset

# ./redfish-bash.sh power restart
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Systems/1/Actions/ComputerSystem.Reset


# ./redfish-bash.sh virtual-media insert http://192.168.58.15/iso/agent-130.iso
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.InsertMedia


# ./redfish-bash.sh virtual-media 
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

# ./redfish-bash.sh virtual-media eject
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Managers/1/VirtualMedia/2/Actions/VirtualMedia.EjectMedia

```

