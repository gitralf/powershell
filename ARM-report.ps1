Param(
[parameter(Position=0,Mandatory=$false)][string]$outfile
)

if ($outfile.Length -eq 0){
    $now=(get-date -UFormat "%Y%m%d%H%M%S").ToString()
    $outfile=$env:TEMP + "\report"+$now+".csv"
}


"output as csv to {0}" -f $outfile

$resources=@()

$location=@{
    "Germany Central"   = "germanycentral"
    "germanycentral"    = "germanycentral"
    "Germany Northeast" = "germanynortheast"
    "germanynortheast"  = "germanynortheast"
}

$line=[ordered]@{
    "SubscriptionID" = ""
    "SubscriptionName" = ""
    "ResourceGroupName" = ""
    "ResourceType" = ""
    "ResourceName" = ""
    "Location" = ""
    "Known" = ""
    "VM_Size" = ""
    "VM_Publisher" = ""
    "VM_Offer" = ""
    "VM_SKU" = ""
    "VM_status" = ""
    "VMC_Size" = ""
    "VMC_OS" = ""
    "VMC_Imagename" = ""
    "Storage_SkuName" = ""
    "Storage_SkuTier" = ""
    "CStorage_Type" = ""
    "Web_State" = ""
    "IOT_Tier" = ""
    "IOT_Capacity" = ""
    "SQL_Kind" = ""
    "SQLDB_Kind" = ""
}


$allsubs=Get-AzureRmSubscription 
$allsubcount=$allsubs.count

$sub=0

$allsubs | foreach-object {
    $res=0
    $sub++

    $current_ARMSubscriptionID=$_.SubscriptionId
    Select-AzureRmSubscription -SubscriptionId $current_ARMSubscriptionID

    $current_ARMSubscriptionName= (Get-AzureRmSubscription -SubscriptionId $current_ARMSubscriptionID).Name

    Select-AzureSubscription -SubscriptionID $current_ARMSubscriptionID -ErrorAction "SilentlyContinue"

    $allResources=Get-AzureRmResource
    
    Write-Progress -Activity "reporting subscriptions" -CurrentOperation "analyzing resources" -Status "current $current_ARMSubscriptionName ($current_ARMSubscriptionID)" -PercentComplete (100*$sub/$allsubcount)


    $allresources | foreach-object {
        $res++
        $thisresource=get-azurermresource -ResourceId $_.ResourceId

        Write-Progress -ID 1 -Activity "find details for resource" -Status $thisresource.Resourcename -PercentComplete (100*$res/$allresources.count)

        $line.SubscriptionId = $current_ARMSubscriptionID
        $line.SubscriptionName = $current_ARMSubscriptionName
        $line.ResourceGroupName = $thisresource.resourcegroupname
        $line.ResourceType = $thisresource.resourcetype
        $line.ResourceName = $thisresource.Resourcename
        $line.Location = $location[$thisresource.location]
        $line.Known = "analyzed"
        

        switch ($thisresource.resourcetype)
        {
            "Microsoft.Compute/virtualMachines" {
                $line.VM_Size = $thisresource.Properties.hardwareProfile.vmSize
                $line.VM_Publisher = $thisresource.Properties.storageProfile.imageReference.publisher
                $line.VM_Offer = $thisresource.Properties.storageProfile.imageReference.offer
                $line.VM_SKU = $thisresource.Properties.storageProfile.imageReference.sku
                $temp=get-azurermvm -ResourceGroupName $thisresource.resourcegroupname -Name $thisresource.Resourcename -status -InformationAction "SilentlyContinue" -WarningAction "SilentlyContinue"
                ForEach ($VMStatus in $temp.Statuses){
                    if ($VMStatus.Code -like "PowerState/*"){
                        $status=$VMStatus.Code.split("/")[1]
                        $line.VM_status = $status
                    }
                }
            }
            "Microsoft.ClassicCompute/virtualMachines" {
                $line.VMC_Size = $thisresource.Properties.hardwareProfile.size
                $line.VMC_OS = $thisresource.Properties.storageProfile.operatingSystemDisk.operatingSystem
                $line.VMC_Imagename = $thisresource.Properties.storageProfile.operatingSystemDisk.sourceImageName
            }
            "Microsoft.Storage/storageAccounts" {
                $line.Storage_SkuName = $thisresource.sku.name
                $line.Storage_SkuTier = $thisresource.sku.tier
            }
            "Microsoft.ClassicStorage/storageAccounts" {
                $type=""
                $type=(get-azurestorageAccount -storageaccountname $thisresource.resourcename -ErrorAction "SilentlyContinue").AccountType
                $line.CStorage_Type = $type
            }
            "Microsoft.Web/sites" {
                $line.Web_State = $thisresource.Properties.state
            }
            "Microsoft.Devices/IotHubs" {
                $line.IOT_Tier = $thisresource.sku.tier
                $line.IOT_Capacity = $thisresource.sku.capacity.tostring()      
            }
            "Microsoft.Sql/servers" {
                $line.SQL_Kind = $thisresource.Kind 
            }
            "Microsoft.Sql/servers/databases" {
                $line.SQLDB_Kind = $thisresource.Kind
            }
            "Microsoft.Network/networkInterfaces" {}
            "Microsoft.Network/networkSecurityGroups" {}
            "Microsoft.Network/publicIPAddresses" {}
            "Microsoft.Network/virtualNetworks" {}
            "Microsoft.Web/serverFarms" {}
            "Microsoft.ClassicCompute/domainNames" {}
            "Microsoft.ClassicNetwork/virtualNetworks" {}
            "default" {
                $line.Known = "unhandled ResourceType"
            }
        }

        $resources += New-Object psobject -Property $line
        $line=@{}
    }
}
Write-Progress -Activity "writing output"  -CurrentOperation "preparing CSV"  -PercentComplete (50)

$resources | Export-Csv -Path $outfile -NoTypeInformation

Write-Progress -Activity "wrinting output" -CurrentOperation "writing outfile" -PercentComplete (100)
