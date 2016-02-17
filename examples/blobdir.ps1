function blobdir {
    param(
    [parameter(Position=0, Mandatory=$false)][string]$account,
    [parameter(Position=1, Mandatory=$false)][string]$container
    )

    if (-not $account) {
    #empty call, list storage accounts
	    get-azurestorageaccount |select label,location,accounttype
    } elseif (-not $container){
    #account given, list containers
	    $context=New-AzureStorageContext -StorageAccountName $account -StorageAccountKey (get-azurestoragekey -StorageAccountName $account|select -ExpandProperty Primary)
	    get-azurestoragecontainer -context $context
    } else {
	    $context=New-AzureStorageContext -StorageAccountName $account -StorageAccountKey (get-azurestoragekey -StorageAccountName $account|select -ExpandProperty Primary)
	    get-azurestorageblob -context $context -container $container
    }
}