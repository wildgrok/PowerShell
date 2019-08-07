#========================================================================
# SQLSMO_WorkFlow_CodeBlocks.ps1
# version in C:\Users\jorgebe\Documents\powershell\workflows
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   8/1/2019
# Created by:   jorgebe
# used by SQLSMO_WorkFlow.ps1
# Called from SQLSMO_WorkFlow.cmd

# Last modified: 
 
#========================================================================

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

##CHANGED 7/25/2019
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
FileId               : 1
CreateLSN            : 0
DropLSN              : 0
UniqueId             : 00000000-0000-0000-0000-000000000000
ReadOnlyLSN          : 0
ReadWriteLSN         : 0
BackupSizeInBytes    : 3997696
SourceBlockSize      : 4096
FileGroupId          : 1
LogGroupGUID         : 
DifferentialBaseLSN  : 410000000048000037
DifferentialBaseGUID : 83b35079-10a4-4726-892a-bef805b67144
IsReadOnly           : False
IsPresent            : True
TDEThumbprint        : 

LogicalName          : ActionTags_Log
PhysicalName         : F:\SQLLOGS\ActionTags_Log.ldf
Type                 : L
FileGroupName        : 
Size                 : 14417920
MaxSize              : 35184372080640
FileId               : 2
CreateLSN            : 0
DropLSN              : 0
UniqueId             : 00000000-0000-0000-0000-000000000000
ReadOnlyLSN          : 0
ReadWriteLSN         : 0
BackupSizeInBytes    : 0
SourceBlockSize      : 4096
FileGroupId          : 0
LogGroupGUID         : 
DifferentialBaseLSN  : 0
DifferentialBaseGUID : 00000000-0000-0000-0000-000000000000
IsReadOnly           : False
IsPresent            : True
TDEThumbprint        : 
BackupName             : ActionTags_backup_2015_05_11_000029_6076771
BackupDescription      : 
BackupType             : 1
ExpirationDate         : 
Compressed             : 1
Position               : 1
DeviceType             : 2
UserName               : CARNIVAL\_sql_executive
ServerName             : CCLUATDTSDB1
DatabaseName           : ActionTags
DatabaseVersion        : 782
DatabaseCreationDate   : 12/12/2014 3:29:53 PM
BackupSize             : 4294656
FirstLSN               : 410000000055200037
LastLSN                : 410000000058400001
CheckpointLSN          : 410000000055200037
DatabaseBackupLSN      : 410000000048000037
BackupStartDate        : 5/11/2015 12:00:30 AM
BackupFinishDate       : 5/11/2015 12:00:31 AM
SortOrder              : 52
CodePage               : 0
UnicodeLocaleId        : 1033
UnicodeComparisonStyle : 196609
CompatibilityLevel     : 120
SoftwareVendorId       : 4608
SoftwareVersionMajor   : 12
SoftwareVersionMinor   : 0
SoftwareVersionBuild   : 2402
MachineName            : CCLUATDTSDB1
Flags                  : 512
BindingID              : 16df0e8b-1ad2-4615-a610-6ee9afd5a7bb
RecoveryForkID         : d5958255-6951-4a04-bf12-efe6601f9fc3
Collation              : SQL_Latin1_General_CP1_CI_AS
FamilyGUID             : 3f506e55-8616-4ec3-8655-612e511372b3
HasBulkLoggedData      : False
IsSnapshot             : False
IsReadOnly             : False
IsSingleUser           : False
HasBackupChecksums     : False
IsDamaged              : False
BeginsLogChain         : False
HasIncompleteMetaData  : False
IsForceOffline         : False
IsCopyOnly             : False
FirstRecoveryForkID    : d5958255-6951-4a04-bf12-efe6601f9fc3
ForkPointLSN           : 
RecoveryModel          : SIMPLE
DifferentialBaseLSN    : 
DifferentialBaseGUID   : 
BackupTypeDescription  : Database
BackupSetGUID          : 405d781e-f106-4023-a986-d3b11f944d48
CompressedBackupSize   : 717226
Containment            : 0

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
$url = '\\Ccldevsql4\devsql2\SQLBACKUPS\SQLBackupUser'
$filter= 'ZZZ_Deleteme_1_*.bak'
$lst = (Invoke-Command -ScriptBlock $GetLatestBackup -ArgumentList ($url, $filter))
$lst
#>



