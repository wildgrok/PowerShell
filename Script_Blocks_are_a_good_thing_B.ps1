# Script_Blocks_are_a_good_thing_B.ps1
# using a script block
$ExecuteSQL = 
{	
	param ($ServerInstance, $Query, $Database)
	$QueryTimeout=0
	$conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True;database=" + $Database
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


#Sample use:
$server = "WORKSTATION\Sqlexpress"
$database = "AdventureWorks2017"
$query = 'select top 2 [FirstName],[LastName],[EmailPromotion] from Person.Person'
$r = Invoke-Sqlcmd3_db $server $query $database 
$r 
