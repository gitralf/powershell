Param(
    [parameter(mandatory=$false)][string]$out
)

$now=(get-date -UFormat "%Y%m%d%H%M%S").ToString()

if ($out.Length -eq 0){
    $out=$env:TEMP + "\report"+$now+".htm"
}

"output goes to {0}" -f $out


$sub=Get-AzureRmSubscription

$Resources=Get-AzureRmResource
$nrResources=$Resources.count

$Resourcegroups=Get-AzureRmResourceGroup
$nrResourcegroups = $Resourcegroups.Count

$output = "
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

$output += "
  <body>
    <h1>Azure Inventory</h1>
    <table id=inventory width='50%'>
      <tr>
        <td>
            created:
        </td>
        <td>
            {0}
        </td>
    </tr>
    <tr>
        <td>
            Tenant-ID:
        </td>
        <td>
            {1}
        </td>
    </tr>
    <tr>
        <td>
            Subscription-ID:
        </td>
        <td>
                {2}
        </td>
    </tr>
    <tr>
        <td>
            Subscription name:
        </td>
        <td>
            {3}    
        </td>
    </tr>
</table>" -f $now,$sub.TenantId,$sub.SubscriptionId,$sub.Name

$output += "
<hr>
<h1>
    Resourcegroups Overview
</h1>

<p>Total: {0}</p>

<table id=inventory>
    <tr>
        <th align='left'>
            Resourcegroupname
        </th>
        <th align='left'>
            Location
        </th>
    </tr>
" -f $nrResourcegroups

Get-AzureRmResourceGroup | ForEach-Object {
    $output += "<tr><td><a href='#{0}'>{0}</a></td><td>{1}</td></tr>`n" -f $_.ResourceGroupName,$_.Location
}

$output +="</table>

<hr>
<h1> Resourcegroups with resources </h1>
"

foreach ($resourcegroup in $Resources){
    $resourcegroupname=$resourcegroup.ResourceGroupName 
    $output +="
    <h2 id='{0}'>{0}</h2>
    <table id=inventory width='75%'>
    <th>Name</th><th>Type</th>
    " -f $_.ResourceGroupName
    $detail=""
    $Resources | Where-Object {$_.resourcegroupname -eq $resourcegroupname}| ForEach-Object {
        $thisresource=$_
        $linkname=$resourcegroupname+"_"+$thisresource.Name
        $output += "<tr><td><a href='#{0}'>{1}</td><td>{2}</td></tr>" -f $linkname,$thisresource.Name,$thisresource.resourcetype

        $detail +="<h3 id="+$linkname+">Details for "+$thisresource.Name+" ("+$resourcegroupname+")</h3>"
$linkname
        switch ($_.resourcetype) {

            "Microsoft.Compute/virtualMachines" {
                $detail+="<table id=inventory>`n"
                $vm=get-azurermvm -Name $thisresource.Resourcename -ResourceGroupName $resourcegroupname -WarningAction "SilentlyContinue"
                $detail+="<tr><td>VM size</td><td>"+$vm.HardwareProfile.vmSize+"</td></tr>`n"
                
                if ($vm.StorageProfile.ImageReference){
                    $detail+="<tr><td>Image offer</td><td>"+$vm.storageProfile.imagereference.offer+"</td></tr>"
                    $detail+="<tr><td>Image SKU</td><td>"+$vm.storageProfile.ImageReference.Sku+"</td></tr>"
                    $detail+="<tr><td>Image publisher</td><td>"+$vm.storagProfile.imageReference.publisher+"</td></tr>"
                }
                $temp=get-azurermvm -ResourceGroupName $thisresource.resourcegroupname -Name $thisresource.Resourcename -status -InformationAction "SilentlyContinue" -WarningAction "SilentlyContinue"
                ForEach ($VMStatus in $temp.Statuses){
                    if ($VMStatus.Code -like "PowerState/*"){
                        $status=$VMStatus.Code.split("/")[1]
                        $detail+="<tr><td>PowerState</td><td>"+$status+"</td></tr>"
                    }
                }
                $detail+="</table>`n"
            }
            "Microsoft.Storage/storageAccounts" {
                $detail+="<table id=inventory>`n"
                $detail+="<tr><td>SKU name</td><td>"+$thisresource.sku.name+"</td></tr>"
                $detail+="<tr><td>SKU tier</td><td>"+$thisresource.sku.tier+"</td></tr>"
                $detail+="</table>`n"
            }
            "Microsoft.Web/sites" {
                $detail+="<table id=inventory>`n"
                $detail+="<tr><td>State:</td><td>"+$thisresource.Properties.state+"</td></tr>"

                foreach ($hostname in $thisresource.Properties.hostNames){
                    $detail+="<tr><td>hostname</td><td>"+$hostname+"</td></tr>"
                }
                $detail+="</table>`n"
            }
            Default {}
        }
    }
    $output +="</table>"+$detail

}




$output+="
  </body>
</html>"

$output | Out-File -filepath $out 