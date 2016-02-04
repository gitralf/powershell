$sourceStorageAccountName = "storage01"
$sourceStorageaccountKey = Get-AzureStorageKey -StorageAccountName $sourceStorageAccountName |select -ExpandProperty Primary
$sourceStorageContext = New-AzureStorageContext -StorageAccountName $sourceStorageAccountName -StorageAccountKey $sourceStorageaccountKey
$sourceContainer = "cont01"
$sourceBlob = "wichtigset-azuresub.zip"

$destStorageAccountName = "storage02"
$destStorageAccountKey = Get-AzureStorageKey -StorageAccountName $destStorageAccountName |select -ExpandProperty Primary
$destStorageContext = New-AzureStorageContext -StorageAccountName $destStorageAccountName -StorageAccountKey $destStorageAccountKey
$destContainer = "cont02"

Start-AzureStorageBlobCopy -SrcBlob $sourceBlob -SrcContainer $sourceContainer -Context $sourceStorageContext -DestContainer $destContainer -DestContext $destStorageContext
