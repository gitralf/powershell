# Pre:
# username and password ready

$cred=Get-Credential

# already created a new certificate and placed it in certificate store (normally "My")
# so give the name of this new certificate

$name_of_new_cert="AzureMgmt"

# be sure that your current subscription is active, otherwise we will use the wrong ID
$subID = (get-azuresubscription -Current).subscriptionID 

# or enter the subscriptionID manually by uncommenting the following line
#$subID = "whatever-your-id-is"

$xmlframe=@'
<?xml version="1.0" ?>
<SubscriptionCertificate xmlns="http://schemas.microsoft.com/windowsazure">
  <SubscriptionCertificatePublicKey></SubscriptionCertificatePublicKey>
  <SubscriptionCertificateThumbprint></SubscriptionCertificateThumbprint>
  <SubscriptionCertificateData></SubscriptionCertificateData>
</SubscriptionCertificate>
'@

$xml=[xml]$xmlframe

$certToUpload=get-childitem Cert:\CurrentUser\My | Where-Object {$_.Subject -match $name_of_new_cert}
if ($certToUpload.count -eq 1){
    write-host "cert gefunden"
} else {
    write-host "cert nicht gefunden"
    exit
}

$publicKey=[System.Convert]::ToBase64String($certToUpload.GetPublicKey())
$thumbprint = $certToUpload.Thumbprint
$certificateData = [System.Convert]::ToBase64String($certToUpload.RawData)

$xml.SubscriptionCertificate.SubscriptionCertificatePublicKey = $publicKey
$xml.SubscriptionCertificate.SubscriptionCertificateThumbprint = $thumbprint
$xml.SubscriptionCertificate.SubscriptionCertificateData = $certificateData

Invoke-WebRequest -uri https://management.core.cloudapi.de/$subID/certificates -Method Post -Headers @{"x-ms-version"="2012-03-01"} -Credential $cred -Body $xml.outerxml -ContentType "application/xml"

