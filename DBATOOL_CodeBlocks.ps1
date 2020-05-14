#========================================================================
# DBATOOL_CodeBlocks.ps1
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   9/25/2019 3:26 PM from SQLSMO2_CodeBlocks.ps1
# version in CCLDEVSHRDDB1\e$\Powershell
# Created by:   jorgebe
# Used by DBATOOL.ps1 in e:\Powershell
# Last modified: 
# 7/29/2019: fixed filter in getlatestbackup in SQLSMO2.ps1
# 7/25/2019: fixed GetBackupInfo (removed extra parameter) in SQLSMO2.ps1
# 6/24/2019 commented sqlfileheader call (causing timeouts)

# Organization: 
# Filename:     
#========================================================================
$SERVERNAME     = 'CCLDEVSHRDDB1\DEVSQL2'
$WORKFOLDER     = 'E:\POWERSHELL'
$SQLFOLDER      = $WORKFOLDER + '\DBATOOL_SQL'

#Set-Location $WORKFOLDER

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

$GetBackupInfo = 
{
	param ($server, $backupfile)
<#
Sample use:
$bkfile = '\\Ccluatdtsdb1\PRODUCTIONBACKUPS\ActionTags_backup_2015_05_11_000029_6076771.bak'
$d = GetBackupInfo $server $bkfile
foreach ($x in $d)
{
	foreach ($y in $x.sqlfilelist)	{$y}
}

LogicalName          : ActionTags_Data
PhysicalName         : G:\SQLDATA\ActionTags_data.mdf
Type                 : D
FileGroupName        : PRIMARY
Size                 : 52428800
MaxSize              : 35184372080640
...
LogicalName          : ActionTags_Log
PhysicalName         : F:\SQLLOGS\ActionTags_Log.ldf
Type                 : L
FileGroupName        : 
Size                 : 14417920
MaxSize              : 35184372080640

Using properties:
$d.sqlfilelist.logicalname gives
ActionTags_Data
ActionTags_Log
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
	$filter = 'DATABASE_*.bak'
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
$url = '\\Cclprddtsdb1e\sqlbackups\SQLBackupUser'
$filter= 'Goccl_Sitecore_Core_*.bak'
$lst = (Invoke-Command -ScriptBlock $GetLatestBackup -ArgumentList ($url, $filter))
$lst
#>


#new 9/30/2019
$GetFolderFiles = 
<# Brings list of files based on filter and on column to sort (default is Name) #>
{	
	param ($url, $filter='*.*', $sort='Name')
	$list = [System.Collections.ArrayList]@()
#    $list = [System.Collections.ArrayList]::new()
#    $lst2 = Get-ChildItem  $url  | Sort-Object -Property LastWriteTime -Descending #-ErrorAction SilentlyContinue 
	$lst2 = Get-ChildItem  $url  | Sort-Object -Property $sort #-Descending #-ErrorAction SilentlyContinue 
	foreach ($k in $lst2)
	{
		if ($k.name -like $filter)
		{
			[void]$list.Add($k.Name)
#            $list.Add($k.Name)
		}
	}
	return $list
}
<#
$url = '\\Ccldevsql4\devsql2\SQLBACKUPS\SQLBackupUser'
$filter= 'ZZZ_Deleteme_1_*.trn'
$lst = (Invoke-Command -ScriptBlock $GetFolderFiles -ArgumentList ($url, $filter, 'Name'))
$lst
$lst = (Invoke-Command -ScriptBlock $GetFolderFiles -ArgumentList ($url, $filter, 'LastWriteTime'))
$lst
#>

