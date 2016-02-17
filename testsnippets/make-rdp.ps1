function makerdp {
param(
[parameter(Position=0, Mandatory=$true)][string]$vmname
)

$vm=get-azurevm| where {$_.name -eq $vmname}
$service=$vm.Servicename
$depl=get-azuredeployment -servicename $service
$ip=$depl.Virtualips.Address

$endpointrdp=$vm.VM.ConfigurationSets.InputEndPoints | where {$_.LocalPort -eq 3389}
$port=$endpointrdp.Port

$arguments="/v ${ip}:${port}"
start-process "mstsc.exe" -argumentlist $arguments
 
}