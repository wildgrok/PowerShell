#List_AD_Computers
#Copy in ccldevshrddb1\e$\Powershell
#Last edited:
#6/7/2019: Added population of table
#6/6/2019: changed filter for computers

<#
All the correct SQL Servers are not on the list - 
Need to refine this automated process of loading server names to the master application list: 
Should capture all new non production SQL servers that are added to AD. -  
Look for CCLDEV*SQL* or CCLDEV*DB* or CCLTST*SQL* or CCLTST*DB* or CCLUAT*SQL* or CCLUAT*DB*.
#>

$global:SERVERNAME = "CCLDEVSHRDDB1\DEVSQL2"
$ErrorActionPreference = "silentlycontinue"

$ExecuteSQL = 
{	
	param ($ServerInstance, $Query, $Database)
	$QueryTimeout=600
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

Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, 'truncate table [Master_Application_List].[dbo].[AD Detected Servers]', "master")




$strFilter = "computer"
$objDomain = New-Object System.DirectoryServices.DirectoryEntry 
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchRoot = $objDomain
$objSearcher.SearchScope = "Subtree" 
$objSearcher.PageSize = 100000 

$objSearcher.Filter = "(objectCategory=$strFilter)"

$colResults = $objSearcher.FindAll()

foreach ($i in $colResults) 
{
        $objComputer = $i.GetDirectoryEntry()
		$Name = $objComputer.Name.ToString()
#		if (  $Name.StartsWith('CCLTST') -or $Name.StartsWith('CCLUAT') -or $Name.StartsWith('CCLDEV') -or $Name.StartsWith('CCLPRD')  -and ($Name.Contains('DB') -or $Name.Contains('SQL') )) 
		#Look for CCLDEV*SQL* or CCLDEV*DB* or CCLTST*SQL* or CCLTST*DB* or CCLUAT*SQL* or CCLUAT*DB*
		if 
		(  	
			$Name.StartsWith('CCLTST') -or $Name.StartsWith('CCLUAT') -or $Name.StartsWith('CCLDEV') `
			-and ($Name.Contains('DB') -or $Name.Contains('SQL') )
		) 	
		{
#        	Get-WMIObject Win32_BIOS -computername $Name -ErrorAction SilentlyContinue 
			Write-Host 	$Name
			$s = 'INSERT INTO [Master_Application_List].[dbo].[AD Detected Servers]  ([Servers]) '
			$s = $s + " VALUES ('" + $Name + "')"
			Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $s, "master")
		}		
}    