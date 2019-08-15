#Jobs_CodeBlocks.ps1
#Used from Jobs_Sample.ps1


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

$GetBackupInfo = 
{
	param ($server, $backupfile)
<#
Sample use:
$bkfile = '\\servername\PRODUCTIONBACKUPS\DBNAME_backup_2015_05_11_000029_6076771.bak'
$d = GetBackupInfo $server $bkfile
foreach ($x in $d)
{
	foreach ($y in $x.sqlfilelist)	{$y}
}

LogicalName          : DBNAME_Data
PhysicalName         : G:\SQLDATA\DBNAME_data.mdf
Type                 : D
FileGroupName        : PRIMARY
Size                 : 52428800
...
LogicalName          : DBNAME_Log
PhysicalName         : F:\SQLLOGS\DBNAME_Log.ldf
Type                 : L
FileGroupName        : 
Size                 : 14417920
...
Using properties:
$d.sqlfilelist.logicalname gives
DBNAME_Data
DBNAME_Log
#>

	$dict_backup = @{}
	$sqlfilelist 	= 'SET NOCOUNT ON RESTORE FILELISTONLY FROM DISK = ' + [char]39 + $backupfile + [char]39
	$dict_backup['sqlfilelist'] = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $sqlfilelist, "master"))
	return $dict_backup
}


$GetLatestBackup = 
<#	
	Returns folder contents sorted by modified date
    Sample use:
    $backupfolder = '\\SERVERNAME\SQLBackups1\SQLBackupUser'
	Filter is case sensitive
	$filter = 'DatabaseName_*.bak'
    This brings all files:
    $lst = (Invoke-Command -ScriptBlock $GetLatestBackup -ArgumentList ($backupfolder)
    Here we bring a subset using filter string
    $lst = (Invoke-Command -ScriptBlock $GetLatestBackup -ArgumentList ($backupfolder, $filter)

#>
{	
	param ($url, $filter='*.bak')
	
	$lst2 = Get-ChildItem  $url  | Sort-Object -Property LastWriteTime -Descending #-ErrorAction SilentlyContinue 
	foreach ($k in $lst2)
	{
		if ($k.Name -like $filter)
		{
			return $k.Name
		}
	}
}
<# 
$url = '\\servername\sqlbackups\SQLBackupUser'
$filter='DBNAME_*.bak'
$lst = (Invoke-Command -ScriptBlock $GetLatestBackup -ArgumentList ($url, $filter))
$lst
#>

$GetBackups = 
<#
	Brings list of backups based on filter
#>
{	
	param ($url, $filter='*.bak')
	$list = [System.Collections.ArrayList]@()
	$lst2 = Get-ChildItem  $url  | Sort-Object -Property LastWriteTime -Descending #-ErrorAction SilentlyContinue 
	foreach ($k in $lst2)
	{
		if ($k.name -like $filter)
		{
			$list.Add($k)
		}
	}
	return $lst2
}

