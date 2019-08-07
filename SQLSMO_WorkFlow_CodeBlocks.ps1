#========================================================================
# SQLSMO_WorkFlow_CodeBlocks.ps1
# version in C:\Users\jorgebe\Documents\powershell\workflows
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   8/1/2019
# Created by:   jorgebe
# used by SQLSMO_WorkFlow.ps1
# Called from SQLSMO_WorkFlow.cmd

# Last modified: 
#8/7/2019 tested restoredabase and restorelogs using workflow (but with the jobs inside) ok
#8/7/2019 tested restorelogs
 
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


$RestoreDatabase = 
{
	#$dbname1 is source db, $dbname2 is destination db
	param ($server,$backupfile, $dbname1, $dbname2, $logfolder, $datafolder, $restore_options)
  #needed to import ExecuteSQL, GetLatestBackup, GetBackupInfo used by RestoreDatabase
. C:\Users\jorgebe\Documents\powershell\WorkFlows\SQLSMO_WorkFlow_CodeBlocks.ps1	

<#
        Restores the database from given backup file to given data and log folders
        Uses file names based on database name with _Data and _Log suffixes
		GetBackupInfo returns dictionary with these keys populated
		$dict_backup['sqlfilelist'] 
		$dict_backup['sqlfileheader'] 
		
		Options for $restore_options['restore_type'] are:
		DATABASE
		DIFFERENTIAL
		If option is LOG returns 
		options for $restore_options['recovery'] are:
		RECOVERY
		NORECOVERY		
#> 	
	
	# just checking 
	if ($restore_options['restore_type'] -eq 'LOG') { return }	
	
	# if passing a folder get latest backup on it
	if ($backupfile -like '*.bak')
	{
		"Restoring from file"
		$backupfile2 = $backupfile
		$backupfile
	}
	else
	{
		"Latest backup from folder"
		$filter = $dbname1 + '_*.bak'
		$bkfile = (Invoke-Command -ScriptBlock $GetLatestBackup -ArgumentList ($backupfile, $filter))
		$backupfile2 = $backupfile + '\' + $bkfile
		$backupfile2		
	}
	
	$dict_backup = (Invoke-Command -ScriptBlock $GetBackupInfo -ArgumentList ($server, $backupfile2))

	# Start building the restore SQL
    $s = 'USE MASTER RESTORE DATABASE [' + $dbname2 + '] FROM DISK =' + [char]39 + $backupfile2 + [char]39 + ' WITH '
    $filecount = 0
    $suffix2 = ''
	#loop for database files
	foreach( $x in $dict_backup.sqlfilelist)
	{
		$ext = [System.IO.Path]::getextension($x.PhysicalName)
		if ($filecount -gt 0) # after 2 values (0 and 1) we add one to the file name
		{
            $suffix2 = $filecount.ToString()
		}	
		if ($x.Type -eq 'L')
		{
            $suffix = 'Log'
            $logfilename = $x.logicalname
			$file_renamed = $dbname2 + '_' + $suffix + $ext
			$s = $s + ' MOVE ' + [char]39 + $x.logicalname + [char]39 + ' TO ' + [char]39 + $logfolder + '\' + $file_renamed + [char]39 + ', '
		}
        else  # any other type (D,F,S) we put in the Data folder
		{
            $suffix = 'Data'
			$file_renamed = $dbname2 + '_' + $suffix + $suffix2 + $ext
			$s = $s + ' MOVE ' + [char]39 + $x.logicalname + [char]39 + ' TO ' + [char]39 + $datafolder + '\' + $file_renamed + [char]39 + ', '
		}       
        $filecount = $filecount + 1
	} # end of database file loop	
	
	$s = $s + ' NOUNLOAD, ' + $restore_options['recovery'] + ', STATS = 10'
    if ($restore_options['replace'] -eq $True)
	{
        $s = $s + ', REPLACE;' +  [char]13 + [char]10
	}	
		
    # Doing the actual restore here. NEW: added code to kill connections in the same execution	
	$s1 =       'DECLARE @kill varchar(8000) = ' + [char]39 + [char]39 + ';'
    $s1 = $s1 + ' SELECT @kill = @kill + ' + [char]39 + 'kill ' + [char]39 + '  + CONVERT(varchar(5), spid) + ' + [char]39 + ';' + [char]39
    $s1 = $s1 + ' FROM master..sysprocesses WHERE dbid = db_id(' + [char]39 + $dbname2 + [char]39 + ') '
    $s1 = $s1 + ' EXEC(@kill); '
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s1, "master"))
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s, "master"))
	if ($restore_options['recovery'] -eq 'RECOVERY')
	{
		$s1 = 'ALTER AUTHORIZATION ON DATABASE::[' + $dbname2 + '] TO [sa]' +  [char]13 + [char]10
		$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s1, $dbname2))
	}	
	
	$s3 = $s1 + [char]13 + [char]10 + $s 
	return $s3
}


$RestoreLogs = 
{
  param ($server,$backupfile, $dbname1, $dbname2, $restore_options)
  #param ($server,$backupfile, $dbname, $logfolder, $datafolder, $restore_options)
  # Is this needed? this is not calling extra codeblocks
  # YES IT IS NEEDED - it is calling ExecuteSQL!!!
  . C:\Users\jorgebe\Documents\powershell\WorkFlows\SQLSMO_WorkFlow_CodeBlocks.ps1	
  <#
      Restores the log from given single backup file log or folder with log backups
      Options for $restore_options['restore_type'] are:
      DATABASE
      DIFFERENTIAL
      LOG
      If option is not LOG returns 
      options for $restore_options['recovery'] are:
      RECOVERY
      NORECOVERY	
      Sample
      RESTORE LOG [ZZZ_Deleteme_4] FROM  DISK = N'G:\DEVSQL2\SQLBACKUPS\SQLBackupUser\ZZZ_deleteme_1_1.trn' 
      WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  STATS = 10
      GO
      RESTORE LOG [ZZZ_Deleteme_4] FROM  DISK = N'G:\DEVSQL2\SQLBACKUPS\SQLBackupUser\ZZZ_deleteme_1_2.trn' 
      WITH  FILE = 1,  NOUNLOAD,  STATS = 10
      GO		
  #> 
  # just checking 
  #	if ($restore_options['restore_type'] -eq 'DATABASE') { return }	
	
  # if passing a folder get latest backup on it
  $s = '' 
  if ($backupfile.Trim().EndsWith('.trn') -eq $True) #single backup passed
  {
    "Restoring from file"
    $backupfile		                                                     
    $s = $s + ' RESTORE LOG [' + $dbname2  + '] FROM  DISK = ' + [char]39 + $backupfile + [char]39
    $s = $s + ' WITH FILE = 1, NORECOVERY,  NOUNLOAD;'
    if ($restore_options['recovery'] -eq 'RECOVERY')
    {
      $s = $s + ' RESTORE DATABASE [' + $dbname2 + '] WITH RECOVERY;'
    }
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s, "master")
    #		Set-Content 'C:\Users\jorgebe\Documents\powershell\WorkFlows\out.txt' $s -Force
    return $s
  }
  else #we are restoring from network folder with several backups
  {
    #		Get list of backups sorted by time
    #		"Source folder is " $backupfile
    #		$backupfile = '\\Ccldevsql4\devsql2\SQLBACKUPS\SQLBackupUser'
    $bklist = Get-ChildItem  $backupfile  | Sort-Object -Property LastWriteTime -Descending
    #		Set-Content 'C:\Users\jorgebe\Documents\powershell\WorkFlows\out.txt' $bklist -Force
    $bklist2 = ""
    #		$filter = '*.trn'
    $filter = $dbname1 + '_*.trn'
    foreach ($k in $bklist)
    {
      if ($k.Name -like $filter)
      {
        $bklist2 = $k.Name  + "|" + $bklist2
      }
    }
    #removing last |
    $bklist2 = $bklist2.Substring(0,$bklist2.Length-1)
    $lst3 = $bklist2.Split("|")	
		
    # Start building the restore SQL
    $s = ''
    foreach ($m in $lst3)
    {	
                                                                              #remember $backupfile here is a folder
      $s = $s + ' RESTORE LOG [' + $dbname2  + '] FROM  DISK = ' + [char]39 + $backupfile + '\' + $m + [char]39
      $s = $s + ' WITH FILE = 1, NORECOVERY,  NOUNLOAD;'
    }	
    if ($restore_options['recovery'] -eq 'RECOVERY')
    {
      $s = $s + ' RESTORE DATABASE [' + $dbname2 + '] WITH RECOVERY;'
			
    }
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s, "master")
    #		Add-Content 'C:\Users\jorgebe\Documents\powershell\WorkFlows\out.txt' $s -Force
    return $s
  }	
}




