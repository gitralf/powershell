$Authority = "https://login.microsoftonline.de/common"
$Resource = "https://graph.cloudapi.de"
$ClientId = "1b730954-1685-4b74-9bfd-dac224a7b894"
$RedirectUri = [System.Uri]'urn:ietf:wg:oauth:2.0:oob'

$authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext $Authority, $true, ([Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared)
$authResult = $authContext.AcquireToken($Resource, $ClientId, $RedirectUri)
Connect-MsolService -AccessToken ($authResult.AccessToken)
