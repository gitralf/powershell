function use {
param(
[parameter(Position=0, Mandatory=$true)][string]$sub
)
switch($sub){
	bf 	{
		select-azuresubscription -subscriptionname "Internal_Test_Ralf"
		write-host "switched to German Cloud"
		break
		}
	msdn 	{
		select-azuresubscription -subscriptionname "Visual Studio Ultimate mit MSDN"
		write-host "switched to MSDN"
		break
		}
	int 	{
		select-azuresubscription -subscriptionname "Microsoft Azure Internal Consumption"
		write-host "switched to Internal"
		break
		}
}
}