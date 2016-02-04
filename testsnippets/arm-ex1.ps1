#remove before publishing
$password="P@ssw0rd!"


$RGName="dvrg04"
$location="North Europe"

$vhdStorageName=$RGName+"stor01"
$vhdStorageType="Standard_LRS"
$publicIPAddressName=$RGName+"pip01"
$dnsNameForPublicIP =$RGName+"dom01"
$publicIPAddressType="Dynamic"
$virtualNetworkName=$RGName+"vnet01"
$addressPrefix="10.0.0.0/16"
$subnetName= $RGName+"subnet01"
$subnetPrefix="10.0.32.0/24"
$nicname=$RGName+"nic01"
$privateIP="10.0.32.20"
$vmname=$RGName+"vm01"
$vmsize=      "Standard_A1"
$imagePublisher="MicrosoftWindowsServer"
$imageOffer="WindowsServer"
$WindowsOSVersion="2012-R2-Datacenter"
$OSDiskName= $RGName+"osdisc01"
$vhdStorageContainerName="vhds"


$adminname=   "superuser"
$adminpwd=    convertto-securestring $password -AsPlainText -force
$admincred= new-object System.Management.Automation.PSCredential($adminname,$adminpwd)


New-AzureRmResourceGroup -Name $RGName -Location $location

New-AzureRmStorageAccount -ResourceGroupName $RGName -Name $vhdStorageName -Location $location -Type $vhdStorageType

$subnet=New-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetPrefix

$vnet= New-AzureRmVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $RGName -Location $location -AddressPrefix $addressPrefix -Subnet $subnet

$subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet

$publicIP = New-AzureRmPublicIpAddress -ResourceGroupName $RGName -Name $publicIPAddressName -Location $location -AllocationMethod $publicIPAddressType -DomainNameLabel $dnsNameForPublicIP

$nic = New-AzureRmNetworkInterface -ResourceGroupName $RGName -Name $nicname -Subnet $subnet -Location $location -PublicIpAddress $publicIP -PrivateIpAddress $privateIP

$config= New-AzureRmVMConfig -VMName $vmname -VMSize $vmsize | 
    Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmname -credential $admincred -ProvisionVMAgent -EnableAutoUpdate |
    Set-AzureRmVMSourceImage -PublisherName $imagePublisher -Offer $imageOffer -Skus $WindowsOSVersion -Version "latest" |
    Set-AzureRmVMOSDisk -name $OSDiskName -VhdUri "http://$vhdStorageName.blob.core.windows.net/$vhdStorageContainerName/$OSDiskName.vhd" -Caching ReadWrite -CreateOption fromImage |
    Add-AzureRmVMNetworkInterface -Id $nic.Id

New-AzureRmVM -ResourceGroupName $RGName -Location $location -VM $config



