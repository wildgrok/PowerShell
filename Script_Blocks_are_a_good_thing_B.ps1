# Script_Blocks_are_a_good_thing_B.ps1
$ExecuteSQL = # Changing our function to a script block, easy
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
# $server = "WORKSTATION\Sqlexpress"
# $database = "AdventureWorks2017"
$server = "CCLDEVSQL4\DEVSQL2"
$database = "AdventureWorks2008R2"
$query = 'select top 2 [FirstName],[LastName],[EmailPromotion] from Person.Person'
# comparing to the the function call version
# $r = Invoke-Sqlcmd3_db $server $query $database 
# sample using Invoke-Command
# $r = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $query, $database))
$r = & $ExecuteSQL $server $query $database
$r 

