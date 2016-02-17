    while ($copyState.Status -ne "Success")
    {
        $percent = ($copyState.BytesCopied / $copyState.TotalBytes) * 100
        Write-Host "Completed $('{0:N2}' -f $percent)%"
        sleep -Seconds 5
        $copyState = $targetBlob | Get-AzureStorageBlobCopyState
    }
