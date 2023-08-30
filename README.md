# redfish-bash

## Usage

```shell
./redfish-bash.sh
```

```shell
# ./redfish-bash.sh 
Usage : ./redfish-bash.sh bmc username:password command
Example : ./redfish-bash.sh https://192.168.13.146 Administrator:superuser command
available commands:
  system
  systems
  manager
  managers
  bios
  eths

```

```shell
# ./redfish-bash.sh https://192.168.13.146 Administrator:superuser manager
https://192.168.13.146/redfish/v1/Managers/Self

# ./redfish-bash.sh https://192.168.13.146 Administrator:superuser system
https://192.168.13.146/redfish/v1/Systems/Self

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

```