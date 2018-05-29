#Parameter setzen

$dbname="DBTest1"
$fwrule="DBTest1Rule"
$location="Germany Central"

$dbuser="dbadmin"
$dbpass="******"

#wo laufen wir denn?
$ip=(Invoke-WebRequest -Uri "https://api.ipify.org").Content
$sqlsuffix=(get-azureenvironment -Name (Get-AzureSubscription -Current).Environment).SqlDatabaseDnsSuffix

$dbserver=New-AzureSqlDatabaseServer -Location $location -AdministratorLogin $dbuser -AdministratorLoginPassword $dbpass -ErrorAction Stop
New-AzureSqlDatabaseServerFirewallRule -ServerName $dbserver.ServerName -RuleName $fwrule -StartIpAddress $ip -EndIpAddress $ip
New-AzureSqlDatabase -ServerName $dbserver.Servername -DatabaseName $dbname -Edition Standard

#connectionstring bauen
$connectionString = "Server=tcp:" + $dbserver.ServerName + $sqlsuffix + ",1433;Database=" + $dbname + ";User ID=" + $dbuser + "@" + $dbserver.ServerName + ";Password=" + $dbpass + ";Trusted_Connection=False;"

#verbindung öffnen
$Connection=New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$Connection.open()

#tabelle anlegen
$query="create table Person ( name varchar(50) not null primary key, firstname varchar(50) )"
$command = $Connection.CreateCommand()
$command.CommandText = $query
$command.ExecuteNonQuery()

#daten füllen
$query = "insert into Person values('Wigand','Ralf');insert into Person values('Potter','Harry');"
$command = $Connection.CreateCommand()
$command.CommandText = $query
$command.ExecuteNonQuery()

#auslesen
$query="select * from Person;"
$command = $Connection.CreateCommand()
$command.CommandText = $query
$result = $command.ExecuteReader()

for($i=0;$i -le 3; $i = $i+2)
{
    $temp=$result.read()
    $result[0]+", "+$result[1]
}

