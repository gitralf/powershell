#Change Password in Microsoft Cloud Deutschland, Preview

$WebServiceUrl = "https://provisioningapi.microsoftonline.de/provisioningwebservice.svc"
$Authority = "https://login.microsoftonline.de/common"
$ClientId = "1b730954-1685-4b74-9bfd-dac224a7b894"
$RedirectUri = [System.Uri]'urn:ietf:wg:oauth:2.0:oob'
$Resource = "https://graph.cloudapi.de"

$RegistryKeySet = $true
$WebServiceUrl_Path = 'HKLM:\SOFTWARE\Microsoft\MSOnlinePowerShell\Path'

$WebServiceUrl_Current = Get-ItemProperty -Path $WebServiceUrl_Path -Name 'WebServiceUrl'

if ($WebServiceUrl -ine $WebServiceUrl_Current.WebServiceUrl) {
    $RegistryKeySet = $false
    try {
        Set-ItemProperty -Path $WebServiceUrl_Path -Name 'WebServiceUrl' -Value $WebServiceUrl -ErrorAction Stop
        $RegistryKeySet = $true
        Write-Warning ("The Azure AD PowerShell endpoint registry value has " + `
                   "been switched to the new endpoint. ")
    } catch {
        Write-Warning "Unable to change registry key. Please run as administrator."
    }
}

if ($RegistryKeySet)
{
        $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext `
                        $Authority, (-not $SkipAuthorityValidation), ([Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared)
        $authResult = $authContext.AcquireToken($Resource, $ClientId, $RedirectUri)
        Connect-MsolService -AccessToken ($authResult.AccessToken)
}
