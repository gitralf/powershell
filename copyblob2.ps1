$sourceStorageAccountName = "bfone"
$sourceStorageaccountKey = Get-AzureStorageKey -StorageAccountName $sourceStorageAccountName |select -ExpandProperty Primary
$sourceStorageContext = New-AzureStorageContext -StorageAccountName $sourceStorageAccountName -StorageAccountKey $sourceStorageaccountKey
$sourceContainer = "cont01"
$sourceBlob = "set-blackforest.ps1"

$destStorageAccountName = "bftwo"
$destStorageAccountKey = Get-AzureStorageKey -StorageAccountName $destStorageAccountName |select -ExpandProperty Primary
$destStorageContext = New-AzureStorageContext -StorageAccountName $destStorageAccountName -StorageAccountKey $destStorageAccountKey
$destContainer = "cont02"

Start-AzureStorageBlobCopy -SrcBlob $sourceBlob -SrcContainer $sourceContainer -Context $sourceStorageContext -DestContainer $destContainer -DestContext $destStorageContext
