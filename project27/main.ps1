Param(
    [parameter(mandatory=$false)][string]$out
)

if ($out.Length -eq 0){
    $now=(get-date -UFormat "%Y%m%d%H%M%S").ToString()
    $out=$env:TEMP + "\report"+$now+".dot"
}

"output goes to {0}" -f $out


function make-node {
    Param (
        [parameter(mandatory=$true)][string]$nodeID,
        [parameter(mandatory=$true)][string]$nodecolor,
        [parameter(mandatory=$true)][array]$properties
    )
    $node="
    !$nodeID!
    [
        shape = !record!,
        fillcolor=!$nodecolor!,
        style=!filled!,
        label = !"+$properties[0]

    for ($n=1;$n -lt $properties.count; $n++){
        $node += "| "+ $properties[$n] 
    }
    $node +=" !
    ]"
    return $node
}

function make-edge {
    Param (
        [parameter(mandatory=$true)][string]$fromID,
        [parameter(mandatory=$true)][string]$toID,
        [parameter(Mandatory=$false)][string]$style
    )
    if ($style.length -gt 0){
        $edgestyle="[style=$style]"
    } else {
        $edgestyle=""
    }
    $edge="
    !$fromID! -> !$toID! $edgestyle
    "
    return $edge
}

$connect = ""
$graph=""
$showunhandled = $false

$dc=0
$dclimit=30000

("digraph g {
    graph [
        rankdir = !LR!
    ];
    node [
    fontsize = !12!,
    fontname=!Arial!
    ];
    edge [
    ];
").Replace("!",'"') | out-file -filepath $out -force

#subnets are not listed as resource, but only as a connected resource in VNets or NICs
#so first check all VNets and create all the subnet nodes
#also build links from subnet to ipconfig (vnet to subnet later....)

    
#first node is the subscription itself, dotted edges will be drawn to all VMs
$prop=New-Object System.Collections.Generic.List[System.Object]
$thissubscription=Get-AzureRmSubscription
$prop.add($thissubscription.Name)
$graph += make-node -nodeID $thissubscription.ID -nodecolor "white" -properties $prop


$vnets = Get-AzureRmVirtualNetwork
foreach ($vnet in $vnets){
    Write-Progress -Activity "analyzing VNets"  -Status "current $vnet.name" 

    $resourceGroupName = $vnet.ResourceGroupName
    $resourceName = $vnet.Name
    $resourceType="virtualNetworks"
    $resourceLocation=$vnet.location

    foreach ($subnet in $vnet.Subnets){
        $prop=New-Object System.Collections.Generic.List[System.Object]
    
        $prop.add($resourceType+"/Subnet")
        $prop.add($subnet.Name)
        $prop.add($resourceLocation)
        $prop.add($resourceGroupName)

        $subnetID = $subnet.ID
        $address = $subnet.AddressPrefix
        if ($address){
            $prop.add($address)
        }
        $graph += make-node -nodeID $subnetID -nodecolor "blue" -properties $prop

        foreach($ipconfig in $subnet.IpConfigurations){
            $ipconfigID=$ipconfig.id
            if ($ipconfigID){
                $connect+=make-edge -fromID $subnetID -toID $ipconfigID
            }
        }
    }
}

#same for the ipconfigurations: NICs are linked to IPConfigurations, not to a subnet. 
#so create nodes for all IPConfigurations

$nics=Get-AzureRmNetworkInterface
foreach ($nic in $nics){
    Write-Progress -Activity "analyzing Nics"  -Status "current $nic.name" 

    $resourceGroupName = $nic.ResourceGroupName
    $resourceName = $nic.Name
    $resourceType="networkInterface"
    $resourceLocation=$nic.location


    foreach ($ipconfig in $nic.ipconfigurations){
        $prop=New-Object System.Collections.Generic.List[System.Object]
    
        $prop.add($resourceType+"/IpConfiguration")
        $prop.add($ipconfig.Name)
        $prop.add($resourceLocation)
        $prop.add($resourceGroupName)

        $ipconfigID=$ipconfig.ID
        if ($ipconfig.PrivateIpAddress){
            $prop.add($ipconfig.PrivateIpAddress+" ("+$ipconfig.PrivateIpAllocationMethod+")")
        } else {
            #wonder if this can ever happen...?
            $prop.add("no private IP")
        }
        if ($ipconfig.subnet.ID){
            $connect += make-edge -fromID $ipconfigID -toID $ipconfig.subnet.ID
        }
        if ($ipconfig.publicIPAddress.ID){
            $connect += make-edge -fromID $ipconfigID -toID $ipconfig.publicIPAddress.ID
        }
        $graph += make-node -nodeID $ipconfigID -nodecolor "blue" -properties $prop
    }
}


$allResources=Get-AzureRmResource
$allResourcesCount=$allResources.count
foreach ($resource in $allResources){
    
    $prop=New-Object System.Collections.Generic.List[System.Object]
    
    $resourceGroupName = $resource.ResourceGroupName
    $resourceName = $resource.Name
    $resourceType=$resource.resourcetype
    $resourceLocation=$resource.location
    
    Write-Progress -Activity "analyzing resources"  -Status "current $resourceName" -PercentComplete (100*$dc/$allresourcescount)

    $prop.add($resourceType)
    $prop.add($resourceName)
    $prop.add($resourceLocation)
    $prop.add($resourceGroupName)
    
    $fillcolor="red"
    $resourceID = $resource.ResourceID
    $thisresource=Get-AzureRmResource -ResourceId $resourceID
    
    switch ($resourceType){
        "Microsoft.Compute/virtualMachines" {
            $vm=get-azurermvm -Name $thisresource.Resourcename -ResourceGroupName $thisresource.resourcegroupname -WarningAction "SilentlyContinue"
            $prop.add($vm.HardwareProfile.vmSize)
            if ($vm.StorageProfile.ImageReference){
                $prop.add($vm.storageProfile.imageReference.offer)
                $prop.add($vm.storageProfile.imageReference.sku)
                $prop.add($vm.storageProfile.imageReference.publisher)
            }
            $temp=get-azurermvm -ResourceGroupName $thisresource.resourcegroupname -Name $thisresource.Resourcename -status -InformationAction "SilentlyContinue" -WarningAction "SilentlyContinue"
            ForEach ($VMStatus in $temp.Statuses){
                if ($VMStatus.Code -like "PowerState/*"){
                    $status=$VMStatus.Code.split("/")[1]
                    $prop.add($status)
                }
            }
            $vm.networkProfile.Networkinterfaces | ForEach-Object {
                $link = $_.id 
                if ($link){
                    $connect += make-edge -fromID $resourceID -toID $link
                }
            }
            $graph+=make-node -nodeID $resourceID -nodecolor $fillcolor -properties $prop
            $connect+=Make-edge -fromID $thissubscription.ID $resourceID -style "dotted"
            
        }
        # "Microsoft.Storage/storageAccounts" {
        #     $fillcolor="green"
        #     $Storage_SkuName = $thisresource.sku.name
        #     $Storage_SkuTier = $thisresource.sku.tier
        #     $prop.add($Storage_SkuName)
        #     $prop.add($Storage_SkuTier)

        #     $graph+=make-node -nodeID $resourceID -nodecolor $fillcolor -properties $prop
        # }
        # "Microsoft.Web/sites" {
        #     $fillcolor="green"
        #     $prop.add($thisresource.Properties.state)
        #     $thisresource.Properties.hostNames | foreach-object {$prop.add($_)}

        #     $graph+=make-node -nodeID $resourceID -nodecolor $fillcolor -properties $prop
        # }
        # "Microsoft.Devices/IotHubs" {
        #     $fillcolor="green"
        #     $prop.add($thisresource.sku.tier)
        #     $prop.add($thisresource.sku.capacity.tostring())
        # }
        # "Microsoft.Sql/servers" {
        #     $fillcolor="green"
        #     $prop.add($thisresource.Kind) 

        #     $graph+=make-node -nodeID $resourceID -nodecolor $fillcolor -properties $prop
        # }
        # "Microsoft.Sql/servers/databases" {
        #     $fillcolor="green"
        #     $prop.add($thisresource.Kind)

        #     $graph+=make-node -nodeID $resourceID -nodecolor $fillcolor -properties $prop
        # }
        "Microsoft.Network/networkInterfaces" {
            $fillcolor="green"
            $nic=Get-AzureRmNetworkInterface -Name $thisresource.Name -ResourceGroupName $thisresource.resourcegroupname

            foreach ($ipconfig in $nic.IpConfigurations){
                $ipconfigID = $ipconfig.ID
                $connect += make-edge -fromID $resourceID -toID $ipconfigID          
            }

            $vmID=$nic.virtualMachine.Id
            if ($vmID){
                $connect += make-edge -fromID $resourceID -toID $vmID
            }

            $graph+=make-node -nodeID $resourceID -nodecolor $fillcolor -properties $prop
        }
        "Microsoft.Network/networkSecurityGroups" {
            $fillcolor="green"
            $nsg=Get-AzureRmNetworkSecurityGroup -Name $thisresource.name -ResourceGroupName $thisresource.resourcegroupname
            foreach ($rule in $nsg.SecurityRules){
                $prop.add($rule.Name)
            }

            foreach ($subnet in $nsg.Subnets){
                $connect += make-edge -fromID $resourceid -toID $subnet.id
            }

            foreach ($nic in $nsg.NetworkInterfaces){
                $connect += make-edge -fromID $resourceID -toID $nic.ID
            }

            $graph+=make-node -nodeID $resourceID -nodecolor $fillcolor -properties $prop

        }
        "Microsoft.Network/publicIPAddresses" {
            $fillcolor="green"
            $pip=Get-AzureRmPublicIpAddress -Name $thisresource.name -ResourceGroupName $thisresource.resourcegroupname
            $prop.add($pip.Sku.Name)
            $prop.add($pip.IpAddress +" ("+$pip.PublicIpAllocationMethod+")")
            if ($pip.DnsSettings.Fqdn){
                $prop.add($pip.DnsSettings.Fqdn)
            } else {
                $prop.add("no DNS defined")
            }
            $nicID=$pip.IpConfiguration.Id
            if ($nicID){
                $connect += make-edge -fromID $resourceID -toID $nicID
            }

            $graph+=make-node -nodeID $resourceID -nodecolor $fillcolor -properties $prop
        }
        "Microsoft.Network/virtualNetworks" {
            $fillcolor="green"
            $vnet=Get-AzureRmVirtualNetwork -Name $thisresource.name -ResourceGroupName $thisresource.resourcegroupname
            foreach ($prefix in $vnet.AddressSpace.AddressPrefixes){
                $prop.add($prefix)
            }
            $graph += make-node -nodeID $vnet.Id -nodecolor $fillcolor -properties $prop
            foreach ($subnet in $vnet.Subnets){
                if ($subnet.id){
                    $connect +=make-edge -fromID $vnet.ID -toID $subnet.id
                }
            }
        }
        default {
            $fillcolor="yellow"
            if ($showunhandled -eq $true){
                $prop.add("unhandled")
                $graph+=make-node -nodeID $resourceID -nodecolor $fillcolor -properties $prop
            }
        }

    }

    
    $dc++
    if ($dc -gt $dclimit){break}
    

}

$graph+=$connect + "}"

$graph.Replace("!",'"') | Out-File -filepath $out -Append -noClobber -Encoding "ANSI"