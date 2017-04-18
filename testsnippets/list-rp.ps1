$all=Get-AzureRmResourceProvider -ListAvailable
$all | ForEach-Object {
    $namespace=$_.ProviderNamespace
    $types=Get-AzureRmResourceProvider -ProviderNamespace $namespace
    $types | ForEach-Object {
        write-host "$($namespace) $(($_.ResourceTypes).ResourceTypeName)"
    }
}