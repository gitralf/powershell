get-azurevm |foreach {
    $vm=get-azurevm -name $_.Name -servicename $_.ServiceName
    write-host $_.name " is using " -NoNewline
    write-host $vm.VM.OSVirtualHardDisk.MediaLink
}