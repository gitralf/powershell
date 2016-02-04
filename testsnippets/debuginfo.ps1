$DebugPreference="Continue"

write-host "Get-Host"
Get-Host

write-host "Get Azure module"
$(Get-Module Azure).Version

write-host "Get Azure Environment"
Get-AzureEnvironment

write-host "Get-AzureSubscriptions"
Get-AzureSubscription

write_host "Get sample command from Blackforest"
Select-AzureSubscription -SubscriptionName "put your subscription name in here"
Get-AzureLocation

