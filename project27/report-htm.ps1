Param(
    [parameter(mandatory=$false)][string]$outdir,
    [parameter(mandatory=$false)][string]$param_resourcegroup
)

$now=(get-date -UFormat "%Y%m%d%H%M%S").ToString()

if ($outdir.Length -eq 0){
    $outdir=$env:TEMP + "\report"+$now
}

"output goes to {0}" -f $outdir

if(!(Test-Path -Path $outdir )){
    "creating directory..."
    New-Item -ItemType directory -Path $outdir
}

$sub=Get-AzureRmSubscription

$Resources=Get-AzureRmResource 
$nrResources=$Resources.count

if ($param_resourcegroup.length -gt 0){
    $Resourcegroups = Get-AzureRmResourceGroup -Name $param_resourcegroup
} else {
    $Resourcegroups = Get-AzureRmResourceGroup
}
$nrResourcegroups = $Resourcegroups.Count

$outputhead = "
<html>
  <head>
  <style>
  #inventory {
      font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif;
      border-collapse: collapse;
  }
  
  body { 
      font-family: 'Trebuchet MS', Arial, Helvetica, sans-serif;
  }

  #inventory td, #inventory th {
      border: 1px solid #ddd;
      padding: 8px;
      text-align: left;
  }
  
  #inventory tr:nth-child(even){background-color: #f2f2f2;}
  
  #inventory tr:hover {background-color: #ddd;}
  
  #inventory th {
      padding-top: 12px;
      padding-bottom: 12px;
      text-align: left;
      background-color: #4CAF50;
      color: white;
  }
</style>
<title>
        Azure Inventory
    </title>
  </head>
"

$outputmain = $outputhead + "
  <body>
    <h1 id='top'>Azure Inventory</h1>
    <table id=inventory width='50%'>
        <tr><td>created:</td><td>{0}</td></tr>
        <tr><td>Tenant-ID:</td><td>{1}</td></tr>
        <tr><td>Subscription-ID:</td><td>{2}</td></tr>
        <tr><td>Subscription name:</td><td>{3}</td></tr>
    </table>" -f $now,$sub.TenantId,$sub.SubscriptionId,$sub.Name

$outputmain += "
<h1>Resourcegroups</h1>
<p>Total: {0}</p>

<table id=inventory width='50%'>
    <tr><th>Resourcegroupname</th><th>Location</th></tr>
" -f $nrResourcegroups

foreach ($resourcegroup in $Resourcegroups) {
    $outputmain += "<tr><td><a href='{0}.htm'>{0}</a></td><td>{1}</td></tr>`n" -f $resourcegroup.ResourceGroupName,$resourcegroup.Location
}

$outputmain +="</table>
</body>
</html>"

$outputmain | Out-File -filepath $outdir+"\main.htm"

$chapter=0;
$section=0
$subsection=0
$subsubsection=0

foreach ($resourcegroup in $Resourcegroups){
    $resourcegroupname=$resourcegroup.ResourceGroupName 
    $chapter++
    $section=0
    $output = $outputhead +"
    <h1>{0}. Resourcegroup {1}</h2>" -f $chapter,$resourcegroupname

    if ($resourcegroup.tags.keys.length -gt 0){
        $output +"<table id=inventory width='50%'>`n<tr><th>Tag</th><th>Value</th></tr>`n"
    }
    foreach ($key in $resourcegroup.tags.keys){
        $output +="<tr><td>{0}</td><td>{1}</td></tr>`n" -f $key, $resourcegroup.tags[$key]
    }

    $output+="</table>"
    
    $resourcetable = ""
    $Resources | Where-Object {$_.resourcegroupname -eq $resourcegroupname}| ForEach-Object {
        $section++
        $thisresource=$_
        $linkname="{0}#{1}" -f $resourcegroupname,$thisresource.Name

        $resourcetable += "<tr><td><a href='{0}'>{1}</td><td>{2}</td></tr>" -f $linkname,$thisresource.Name,$thisresource.resourcetype
        
        $detailtable += "<h3 id={0}>{1}.{2} Resource {3} in resourcegroup {4}</h3>" -f $linkname,$chapter,$section,$thisresource.Name,$resourcegroupname
        $detailtable += "<table id=inventory width='50%'>`n<tr><th>Attribute</th><th>Value</th></tr>`n"
        $detailtable +="<tr><td>ResourceType</td><td>{0}</td></tr>`n" -f $thisresource.resourcetype
        $tags=""
        foreach ($key in $thisresource.tags.keys){
            $tagstable+="<tr><td>Tag: {0}</td><td>{1}</td></tr>`n" -f $key, $thisresource.tags[$key]
        }

        switch ($thisresource.resourcetype) {

            "Microsoft.Compute/virtualMachines" {
                $vm=get-azurermvm -Name $thisresource.Resourcename -ResourceGroupName $resourcegroupname -WarningAction "SilentlyContinue"
                $detailtable+="<tr><td>VM size</td><td>{0}</td></tr>`n" -f $vm.HardwareProfile.vmSize
                
                if ($vm.StorageProfile.ImageReference){
                    $detailtable+="<tr><td>Image offer    </td><td>{0}</td></tr>" -f $vm.storageProfile.Imagereference.offer
                    $detailtable+="<tr><td>Image SKU      </td><td>{0}</td></tr>" -f $vm.storageProfile.ImageReference.Sku
                    $detailtable+="<tr><td>Image publisher</td><td>{0}</td></tr>" -f $vm.storageProfile.ImageReference.publisher
                }
                $temp=get-azurermvm -ResourceGroupName $resourcegroupname -Name $thisresource.Resourcename -status -InformationAction "SilentlyContinue" -WarningAction "SilentlyContinue"
                ForEach ($VMStatus in $temp.Statuses){
                    if ($VMStatus.Code -like "PowerState/*"){
                        $status=$VMStatus.Code.split("/")[1]
                        $detailtable+="<tr><td>PowerState</td><td>{0}</td></tr>`n" -f $status
                    }
                }
            }
            "Microsoft.Storage/storageAccounts" {
                $detailtable+="<tr><td>SKU name</td><td>{0}</td></tr>" -f $thisresource.sku.name
                $detailtable+="<tr><td>SKU tier</td><td>{0}</td></tr>" -f $thisresource.sku.tier
            }
            "Microsoft.Web/sites" {
                $website=Get-AzureRmWebApp -ResourceGroupName $resourcegroupname -Name $thisresource.name
                $detailtable+="<tr><td>State:</td><td>{0}</td></tr>" -f $website.state

                foreach ($hostname in $website.hostNames){
                    $detailtable+="<tr><td>hostname</td><td>{0}</td></tr>" -f $hostname
                }
            }
            "Microsoft.Sql/servers" {
                $detailtable+="<tr><td>Kind</td><td>{0}</td></tr>" -f $thisresource.Kind
            }
            "Microsoft.Sql/servers/databases" {
                $detailtable+="<tr><td>Kind</td><td>{0}</td></tr>" -f $thisresource.Kind
            }
            "Microsoft.Network/networkInterfaces" {
                $nic = Get-AzureRmNetworkInterface -Name $thisresource.Name -ResourceGroupName $thisresource.resourcegroupname 
                $linkedVMId = $nic.VirtualMachine.Id
                if ($linkedVMId){
                    $linkedVM = Get-AzureRmResource -ResourceId $linkedVMId
                    $detailtable+="<tr><td>attachedTo</td><td><a href='#{0}_{1}'>{2} ({3})</a></td></tr>" -f $linkedVM.Resourcegroupname,$linkedVM.Name,$linkedVM.Name,$linkedVM.Resourcegroupname
                }
                $subsubsection=0
                $extratable=""
                foreach ($ipconfig in $nic.IpConfigurations){
                    $subsubsection++
                    $sublinkname= "{0}_{1}" -f $linkname,$nic.Name
                    
                    $extratable+="<h4 id='{0}'>{1}.{2}.{3}.{4}. IP-Configuration {5} used in {6}</h4>
                    " -f $sublinkname,$chapter,$section,$subsection,$subsubsection,$ipconfig.name,$nic.name
                    $extratable += "<table id=inventory width='50%'>`n<tr><th>Attribute</th><th>Value</th></tr>`n" 
                    $extratable += "<tr><td>Name</td><td>{0}</td></tr>`n" -f $ipconfig.Name
                    $extratable += "<tr><td>PrivateIP</td><td>{0}</td></tr>`n" -f $ipconfig.PrivateIpAddress
                    $extratable += "<tr><td>AllocationMethodPrivateIP</td><td>{0}</td></tr>`n" -f $ipconfig.PrivateIPAllocationMethod
#more might go in here from ipconfig
                    $subnetID=$ipconfig.Subnet.Id
                    $subnetparts=$subnetid.split("/")
                    

                    $extratable += "<tr><td>Subnet</td><td>{0}</td></tr>`n" -f $ipconfig.PrivateIpAddress
                    $extratable+="</table>`n"
                    $detailtable+="<tr><td>IPconfig</td><td><a href='#{0}'>{1}</a></td></tr>`n" -f $sublinkname,$ipconfig.name
                }
 
            }


            Default {
                $detailtable +="<tr><td colspan=2>no handler found</td></tr>"
            }
        }
        $detailtable+=$tagstable + "</table>`n" + $extratable
        $extratable=""
    }
    $output += $resourcetable + $detailtable 

    $output +="</table>{0}</body></html>" -f $detailtable
    $output | Out-File -filepath $outdir+"\"+$resourcegroupname+".htm"
}


