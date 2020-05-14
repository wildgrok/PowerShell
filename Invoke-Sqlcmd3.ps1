$CURRENT_DATABASE = "TableGames"
$WEBMETHODS_DATABASE = "TableGames"
$CURRENT_SERVER   = 'XXDEVSQL3'

function Invoke-Sqlcmd3 ($ServerInstance, $Query)
<#
	Chad Millers Invoke-Sqlcmd3
#>
{
	$QueryTimeout=1200
    $conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True;"
	$conn.ConnectionString=$constring
    $conn.Open()
	if($conn)
    {
    	$cmd=new-object System.Data.SqlClient.SqlCommand($Query,$conn)
    	$cmd.CommandTimeout=$QueryTimeout
    	$ds=New-Object System.Data.DataSet
    	$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    	[void]$da.fill($ds)
    	$conn.Close()
    	$ds.Tables[0]
	}
}

$Query = 'select name from sysdatabases'
Invoke-Sqlcmd3 $CURRENT_SERVER $Query

