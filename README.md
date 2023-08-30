# redfish-bash

## Usage

```shell
./redfish-bash.sh
```

```shell
# ./redfish-bash.sh 
Usage :   ./redfish-bash.sh bmc username:password command [json_path]
Example : ./redfish-bash.sh https://192.168.13.146 Administrator:superuser managers
Example : ./redfish-bash.sh https://192.168.13.146 Administrator:superuser bios '.Attributes.WorkloadProfile'
Available commands : 
  system
  systems
  manager
  managers
  bios
  eths
  power
  power on|off|restart
```

```shell
## ZT
# ./redfish-bash.sh https://192.168.13.146 Administrator:superuser manager
https://192.168.13.146/redfish/v1/Managers/Self
## HPE
# ./redfish-bash.sh https://192.168.14.130 Administrator:Redhat123! manager
https://192.168.14.130/redfish/v1/Managers/1

## ZT
# ./redfish-bash.sh https://192.168.13.146 Administrator:superuser system
https://192.168.13.146/redfish/v1/Systems/Self
## HPE
# ./redfish-bash.sh https://192.168.14.130 Administrator:Redhat123! system
https://192.168.14.130/redfish/v1/Systems/1

# ./redfish-bash.sh https://192.168.13.146 Administrator:superuser eths
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

# ./redfish-bash.sh https://192.168.14.130 Administrator:Redhat123! bios ".Attributes.WorkloadProfile"
vRAN

# ./redfish-bash.sh https://192.168.14.130 Administrator:Redhat123! managers '.VirtualMedia."@odata.id"'
/redfish/v1/Managers/1/VirtualMedia


# ./redfish-bash.sh https://192.168.14.130 Administrator:Redhat123! power
On

# ./redfish-bash.sh https://192.168.14.130 Administrator:Redhat123! power abc
abc is not valid command.

# ./redfish-bash.sh https://192.168.14.130 Administrator:Redhat123! power on
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageArgs":["Power is on"],"MessageId":"iLO.2.16.InvalidOperationForSystemState"}]}}400 https://192.168.14.130/redfish/v1/Systems/1/Actions/ComputerSystem.Reset

# ./redfish-bash.sh https://192.168.14.130 Administrator:Redhat123! power off
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Systems/1/Actions/ComputerSystem.Reset

# ./redfish-bash.sh https://192.168.14.130 Administrator:Redhat123! power restart
{"error":{"code":"iLO.0.10.ExtendedInfo","message":"See @Message.ExtendedInfo for more information.","@Message.ExtendedInfo":[{"MessageId":"Base.1.4.Success"}]}}200 https://192.168.14.130/redfish/v1/Systems/1/Actions/ComputerSystem.Reset

```

