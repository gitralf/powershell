#define variables
$sourceSubscription = "subscriptionname1"
$destSubscription   = "subscriptionname2"

$sourceName    = "old_vm"
$sourceService = "old_service"

$destName      = $sourceName
$destService   = "new_service"
$destStorageName="new_storage"

#switch to source subscription
select-azuresubscription -SubscriptionName $sourceSubscription

#collect information
$sourceVM = Get-AzureVM –Name $sourceName –ServiceName $sourceService 
$sourceVM | Export-AzureVM –Path “c:\temp\export.xml”

$sourceOSDisk = $sourceVm.VM.OSVirtualHardDisk
$sourceDataDisks = $sourceVm.VM.DataVirtualHardDisks

$sourceStoragename = ($sourceOSDisk.MediaLink.Host -split "\.")[0]
$sourceStorageAccount = Get-AzureStorageAccount –StorageAccountName $sourceStorageName
$sourceStorageKey = (Get-AzureStorageKey -StorageAccountName $sourceStorageName).Primary
$sourceContext = New-AzureStorageContext –StorageAccountName $sourceStorageName -StorageAccountKey $sourceStorageKey 

#stop source VM
Stop-AzureVM –Name $sourceName –ServiceName $sourceService 

#switch to target subscription
Select-AzureSubscription -SubscriptionName $destSubscription
Set-AzureSubscription -SubscriptionName $destSubscription -CurrentStorageAccountName $destStorageName

#collect information
$destStorageAccount = Get-AzureStorageAccount -StorageAccountName $destStorageName
$deststoragekey= (Get-AzureStorageKey -StorageAccountName $destStorageName).Primary
$destContext   = New-AzureStorageContext –StorageAccountName $destStorageName -StorageAccountKey $destStorageKey

#loop through all disks
$allDisks = @($sourceOSDisk) + $sourceDataDisks
$destDataDisks = @()

foreach($disk in $allDisks)
{
    $sourceContName = ($disk.MediaLink.Segments[1] -split "\/")[0]
    $sourceBlobName = $disk.MediaLink.Segments[2]
    $destBlobName = $sourceBlobName

    $destBlob = Start-CopyAzureStorageBlob –SrcContainer $sourceContName -SrcBlob $sourceBlobName -DestContainer vhds -DestBlob $destBlobName -Context $sourceContext -DestContext $destContext -Force

    Write-Host "Copying blob $sourceBlobName"

    $copyState = $destBlob | Get-AzureStorageBlobCopyState
    $total=$copyState.TotalBytes
    $start = Get-Date

    while ($copyState.Status -ne "Success")
    {
        $done=$copyState.BytesCopied
        Write-Host "$done von $total"

        sleep -Seconds 10
        $copyState = $destBlob | Get-AzureStorageBlobCopyState
    }
    $ende=get-date
    write-host "copied $total bytes between $start and $ende"

    If ($disk -eq $sourceOSDisk)
    {
                $destOSDisk = $destBlob
    }
    Else
    {
        $destDataDisks += $destBlob
    }
}

#convert file to disk (OS)
Add-AzureDisk -OS $sourceOSDisk.OS -DiskName $sourceOSDisk.DiskName -MediaLocation $destOSDisk.ICloudBlob.Uri

#convert from file to disk (Data)
foreach($currentDataDisk in $destDataDisks)
{
    $diskName = ($sourceDataDisks | ? {$_.MediaLink.Segments[2] -eq $currentDataDisk.Name}).DiskName
    Add-AzureDisk -DiskName $diskName -MediaLocation $currentDataDisk.ICloudBlob.Uri
}

#define new VM
$destVM=New-AzureVMConfig -name $destName -InstanceSize Small -DiskName $sourceOSDisk.DiskName
New-AzureVM –ServiceName $destService –VMs $destVM
