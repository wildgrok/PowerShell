#SQLSMO.ps1
#version in GITHUB

#---------------FUNCTIONS---------------------------------------

function Invoke-Sqlcmd3 ($ServerInstance,$Query)
<#
	Chad Millers Invoke-Sqlcmd3
#>
{
	$QueryTimeout=30
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

function Invoke-Sqlcmd4 ($ServerInstance,$Query)
<#
	Alternative used in multithreading calls (performs better than Invoke-Sqlcmd3 in this case)
#>
{
	$Query = [char]34 + $Query + [char]34
	(sqlcmd -S $ServerInstance -Q $Query -W)
}

function SyncLogins($server, $database)
<#
	Syncs logins for given database
#>
{
$s = @"
    DECLARE @UserName nvarchar(255)
    DECLARE @SQLCmd nvarchar(511)
    DECLARE orphanuser_cur cursor for
    SELECT UserName = name
    FROM sysusers
    WHERE issqluser = 1 and (sid is not null and sid <> 0x0) and suser_sname(sid) is null ORDER BY name
    OPEN orphanuser_cur
    FETCH NEXT FROM orphanuser_cur INTO @UserName
    WHILE (@@fetch_status = 0)
    BEGIN
    select @UserName + ' user name being resynced'
    set @SQLCmd = 'ALTER USER '+@UserName+' WITH LOGIN = '+@UserName
    EXEC (@SQLCmd)
    FETCH NEXT FROM orphanuser_cur INTO @UserName
    END
    CLOSE orphanuser_cur
    DEALLOCATE orphanuser_cur 
"@

	# there is a reason for this ...
	$sync = $s.Replace([char]13, ' ').Replace([char]10, ' ')
	$sync = "USE [" + $database + "] " + $sync
	Invoke-Sqlcmd3 $server  $sync
}

function GetDatabaseInfo($server, $currdb)
<#
Returns dictionary with file logical names as keys, rest of info as rows
Sample use:
$m = GetDatabaseInfo $server $db
$m

Name                           Value                                                                                         
----                           -----                                                                                         
DBDATA_Log             System.Data.DataRow                                                                           
DBDATA_Data            System.Data.DataRow                                                                           
#>
{
	$dict_db = @{}
	$sqlsphelpdb = "SET NOCOUNT ON select name, physical_name, (size * 8/1000) as size, data_space_id from [" + $currdb + "].sys.database_files"
	$z = Invoke-Sqlcmd3 $server  $sqlsphelpdb
	foreach ($x in $z)
	{
		$dict_db[$x.name] = $x
	}
	return $dict_db
#	return $cols
	
}

function GetBackupInfo($server, $backupfile)
<#
Sample use:
$bkfile = '\\SHAREDLOCATION\DBDATA_backup_2015_05_11_000029_6076771.bak'
$d = GetBackupInfo $server $bkfile
foreach ($x in $d)
{
	foreach ($y in $x.sqlfilelist)	{$y}
	foreach ($y in $x.sqlfileheader){$y}
}

LogicalName          : DBDATA_DATA
PhysicalName         : G:\SQLDATA\DBDATA_DATA.mdf
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

LogicalName          : DBDATA_LOG
PhysicalName         : F:\SQLLOGS\DBDATA_LOG.ldf
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

BackupName             : DBDATA_backup_2015_05_11_000029_6076771
BackupDescription      : 
BackupType             : 1
ExpirationDate         : 
Compressed             : 1
Position               : 1
DeviceType             : 2
UserName               : CORPDOMAIN\sqluser
ServerName             : SQLSERVERNAME
DatabaseName           : DBDATA
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
MachineName            : SQLSERVERNAME
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
DBDATA_DATA
DBDATA_LOG
#>
{
	$dict_backup = @{}
	$sqlfileheader 	= 'SET NOCOUNT ON RESTORE HEADERONLY FROM DISK = ' + [char]39  + $backupfile + [char]39 
	$sqlfilelist 	= 'SET NOCOUNT ON RESTORE FILELISTONLY FROM DISK = ' + [char]39 + $backupfile + [char]39
	$dict_backup['sqlfilelist'] = Invoke-Sqlcmd3 $server  $sqlfilelist
	$dict_backup['sqlfileheader'] = Invoke-Sqlcmd3 $server  $sqlfileheader
	return $dict_backup
}
#$bkfile = '\\SQLSERVERNAME\PRODUCTIONBACKUPS\DBDATA_backup_2015_05_11_000029_6076771.bak'
#$d = GetBackupInfo $server $bkfile

function GetColumnNames ($datarow)
<#
	pass a row object, get back list of column names
#>
{
	$cols = @()
	foreach($y in $datarow)
	{
		$cols += $y.ColumnName
	}
	return $cols
}

function DeleteOlderFiles($url, $ext, $days, $dbname)
{
	$d = Get-Date
	$a = @{}
	$files = Get-ChildItem -Filter $dbname*.$ext $url
	if ($files.Count -gt 0)
	{
      foreach ($f in $files)
      {
		write-host  'Checking backup ' $f.Name 'dated '  $f.LastWriteTime 
		if (($d - $f.LastWriteTime).Days -gt $days)
		{
			write-host  'Deleting backup ' $f.Name 'dated '  $f.LastWriteTime
	 		Remove-Item  $url\$f -Force
		}
		else
		{
			write-host  'Keeping backup ' $f.Name 'dated '  $f.LastWriteTime
			$a[$f.Name] = $f.LastWriteTime			
		}
    }	
  }
  $b = $a.GetEnumerator() | Sort-Object 'Value' -Descending
  return $b
}


function GetLatestBackup ($url, $filter='\*.*')
<#	
	Returns folder contents sorted by modified date
    Sample use:
    $backupfolder = '\\SERVERNAME\SQLBackups1\SQLBackupUser'
    This brings all files:
    $lst = GetLatestBackup $backupfolder
    Here we bring a subset using filter string
    $filter = '\DATABASE_*.bak'
    $lst = GetLatestBackup backupfolder filter
#>
{	
	$files = Get-ChildItem -Filter $filter $url | Sort-Object -Property LastWriteTime -ErrorAction SilentlyContinue	
	return $files
}
#to test
#$filter = 'DatabaseName*.trn'
#$url = '\\SQLSERVERNAME\sqlbackups'
#$b = GetLatestBackup $url $filter
#$b[-1]



function RestoreLogs ($dbname, $sourcedb, $bkfolder, $restore_options)
<#
	Builds the sql for the restore of all the logs with desired recovery option
	If there are no logs and the recovery is RECOVERY, it will set the database as recovered
	
	$restore_options['restore_type'] 	=> DIFFERENTIAL DATABASE LOG
	$restore_options['recovery'] 		=> RECOVERY  NORECOVERY
	$restore_options['replace'] 		=> $True $False
	$restore_options['backup_mask']		=> _backup_20*.BAK
	$restore_options['log_mask']		=> _backup_20*.TRN'
	$restore_options['dif_mask']		=> _backup_20*.DIF'
	
	Note: not using a single value for mask variable, we need to have 3 at the same time to locate 
	backup in sequence
	
	--Sample query for reference
	-- check for log backups
    DECLARE backupFiles CURSOR FOR
    SELECT backupFile
    FROM @fileList
    WHERE backupFile LIKE '%.TRN'
    AND backupFile LIKE @dbName + '%'
    AND backupFile > @lastFullBackup
    OPEN backupFiles
    -- Loop through all the files for the database
    FETCH NEXT FROM backupFiles INTO @backupFile
    WHILE @@FETCH_STATUS = 0
    BEGIN
       SET @cmd = 'RESTORE LOG ' + @dbName + ' FROM DISK = '''
           + @backupPath + @backupFile + ''' WITH NORECOVERY'
       PRINT @cmd
       FETCH NEXT FROM backupFiles INTO @backupFile
    END
    CLOSE backupFiles
    DEALLOCATE backupFiles
    -- 6 - put database in a useable state
    SET @cmd = 'RESTORE DATABASE ' + @dbName + ' WITH RECOVERY'
    PRINT @cmd
	
#>
{
	# copy options for clarity:
	$recovery = $restore_options['recovery'] 		
	$BACKUP_MASK = $restore_options['backup_mask']		
	$LOG_MASK = $restore_options['log_mask']		
	

	#first we get latest full backup
	$mask = $sourcedb + $BACKUP_MASK
	$BKFILELIST = GetLatestBackup $bkfolder $mask
	$BKFILE = $BKFILELIST[-1]

	$s = ''
	
	#now we get the list of log files ordered by lastwritetime 
	#VERY IMPORTANT: do not relay in file name for sorting
	$filter = $sourcedb + $LOG_MASK
    $filelist = GetLatestBackup $bkfolder $filter 

	#there may not be backup log files, checking count first
    if ($filelist.Count -eq 0)
	{
#        'No log files for ' + $sourcedb
        if ($recovery -eq 'RECOVERY')
		{
            $s = 'RESTORE DATABASE ' + $dbname + ' WITH RECOVERY' + [char]13 + [char]10
            return $s
		}
	}
    else
	{
        foreach ($x in $filelist)
		{
            if ($x.LastWriteTime -gt $BKFILE.LastWriteTime)  # this means the log file is older than the latest full backup file
			{
                $s = $s + 'RESTORE LOG ' + $dbname + ' FROM DISK = ' + [char]39 + $bkfolder + '\' + $x.Name + [char]39 + ' WITH NORECOVERY' + [char]13 + [char]10
			}
		}
		
		# if recovery option, recover database after last tlog is applied
        if ($recovery -eq 'RECOVERY')
		{
            $s = $s + 'RESTORE DATABASE ' + $dbname + ' WITH RECOVERY' + [char]13 + [char]10
			return $s
		}
		else
		{
			return $s
		}
	}
}





function RestoreDatabase($server,$backupfile, $dbname, $logfolder, $datafolder, $restore_options)
{
<#
        Restores the database from given backup file to given data and log folders
        Uses file names based on database name with _Data and _Log suffixes
		GetBackupInfo returns dictionary with these keys populated
		$dict_backup['sqlfilelist'] 
		$dict_backup['sqlfileheader'] 
		
		Options for $restore_options['restore_type'] are:
		DATABASE
		DIFFERENTIAL
		If option is LOG it calls RestoreLogs 
		
#> 
	# just checking 
	if ($restore_options['restore_type'] -eq 'LOG') { return }
	
	$dict_backup = GetBackupInfo $server $backupfile
	# Start building the restore SQL
    $s = 'USE MASTER RESTORE DATABASE [' + $dbname + '] FROM DISK =' + [char]39 + $backupfile + [char]39 + ' WITH '
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
            $d = $logfolder
            $logfilename = $x.logicalname
			$file_renamed = $dbname + '_' + $suffix + $ext
		}
        else  # any other type (D,F,S) we put in the Data folder
		{
            $suffix = 'Data'
            $d = $datafolder
			$file_renamed = $dbname + '_' + $suffix + $suffix2 + $ext
		}       
        $s = $s + ' MOVE ' + [char]39 + $x.logicalname + [char]39 + ' TO ' + [char]39 + $d + '\' + $file_renamed + [char]39 + ', '
        $filecount = $filecount + 1
	} # end of database file loop		
	$s = $s + ' NOUNLOAD, ' + $restore_options['recovery'] + ', STATS = 10'
    if ($restore_options['replace'] -eq $True)
	{
        $s = $s + ', REPLACE'
	}	
		
    # Doing the actual restore here. NEW: added code to kill connections in the same execution
    $s1 = 'SET NOCOUNT ON DECLARE @kill varchar(8000) = ' + [char]39 + [char]39 + ';'
    $s1 = $s1 + ' SELECT @kill = @kill + ' + [char]39 + 'kill ' + [char]39 + '  + CONVERT(varchar(5), spid) + ' + [char]39 + ';' + [char]39
    $s1 = $s1 + ' FROM master..sysprocesses WHERE dbid = db_id(' + [char]39 + $dbname + [char]39 + ')'
    $s1 = $s1 + ' select @kill; EXEC(@kill); ' + [char]13 + [char]10
    $s = $s1 + $s + [char]13 + [char]10
	return $s
}

function DisplayDataRow ($datarow)
<#
	Translates output of System.Data.DataRow to array of strings
#>
{
	$formatOut = @()
	for ($i=0; $i -le $datarow.Length; $i++)
	{
    	$formatOut = $formatOut + ($datarow[$i].ItemArray -join ",")
	}	
	foreach ($x in $formatout)
	{
		$x
	}
}


function BackupDatabase($dbname, $backupfile, $backup_options)
<#	
		Makes a backup of dbname to backupfile, options are:
		
		backup_options = @{}
		backup_options['backup_type'] => DATABASE LOG DIFFERENTIAL
		backup_options['compression'] => $TRUE $FALSE	
#>

{
	if ($backup_options['backup_type'] -eq 'DATABASE')
	{
       	$s = 'BACKUP DATABASE  [' + $dbname + '] TO DISK = ' + [char]39
       	$s += $backupfile + [char]39 + ' WITH NOFORMAT, INIT, NAME = N' + [char]39
        $s += $dbname + ' ' + $backup_options['backup_type'] + ' Backup' + [char]39
	}
	if ($backup_options['backup_type'] -eq 'DIFFERENTIAL')
	{		
        $s = 'BACKUP DATABASE [' + $dbname + '] TO DISK = ' + [char]39
        $s += $backupfile + [char]39 + ' WITH DIFFERENTIAL, NOFORMAT, INIT, NAME = N' + [char]39
        $s += $dbname + ' Differential Backup' + [char]39
	}
	if ($backup_options['backup_type'] -eq 'LOG')
	{		
        $s = 'BACKUP LOG  [' + $dbname + '] TO DISK = ' + [char]39
       	$s += $backupfile + [char]39 + ' WITH NOFORMAT, INIT, NAME = N' + [char]39
        $s += $dbname + ' ' + $backup_options['backup_type'] + ' Backup' + [char]39
	}
    if ($backup_options['compression'] -eq $True)
	{
        $s += ' , SKIP, NOREWIND, NOUNLOAD, COMPRESSION,  STATS = 10'
	}
    else
	{
        $s += ' , SKIP, NOREWIND, NOUNLOAD,  STATS = 10'
	}
    return $s
}

function DatedString()
<#
	Returns dated string with this format
    2014_12_30_135857_0000000
	
#>
{	
	(get-Date -Format yyyy_MM_dd_HHmmss_0000000).ToString()
}

#----------------------End of functions--------------------------------------------

#Write-Host "called from SQLSMO"

#----------------------Program-----------------------------------------------------


<# TEST OF INVOKE-SQLCMD3 START

$server = "localhost\sql2014"
$db = "AdventureWorks2012"
$Query = 
@"
SELECT TOP 10 [BusinessEntityID]
      ,[PersonType]
      ,[NameStyle]
      ,[Title]
      ,[FirstName]
      ,[MiddleName]
      ,[LastName]
      ,[ModifiedDate]
  FROM [AdventureWorks2012].[Person].[Person]
"@
$Query
Invoke-Sqlcmd3 $Server $Query

TEST OF INVOKE-SQLCMD3 END
#>


<# TEST OF INVOKE-SQLCMD4 START

#$svr = 'localhost\sql2014'
#$q = 'set nocount on select name from master.dbo.sysdatabases'
#Invoke-Sqlcmd4 $svr $q

TEST OF INVOKE-SQLCMD4 END
#> 
 
#TEST SECTION OF RESTORE DATABASE - START
<#
$restore_options = @{}
$restore_options['restore_type'] = 'DATABASE'
$restore_options['recovery'] = 'RECOVERY'
$restore_options['replace'] = $True
$server = "SQLSERVERNAME.9999"
$dbname = 'ssadserver'
$datafolder = 'F:\SQLDATA'
$logfolder = 'E:\SQLLOGS'
$filter = 'ssadserver_backup*.bak'
$url = '\\SHARENEMA\Backup\DBBACKUP_Backups'
$bklist = GetLatestBackup $url $filter
Write-Host 'list of backups'
foreach ($x in $bklist)
{	
	$x.Name
}
$backupfile = $URL + '\' + $bklist[-1]
Write-Host 'latest backup is'
$backupfile.Name
$sql = RestoreDatabase $server $backupfile $dbname $logfolder $datafolder $restore_options
$sql
#>
#TEST SECTION OF RESTORE DATABASE - END


##TEST SECTION OF RESTORE DIFFERENTIAL - START
<#
$restore_options = @{}
$restore_options['restore_type'] = 'DIFFERENTIAL'
$restore_options['recovery'] = 'RECOVERY'
$restore_options['replace'] = $True
$server = 'localhost\sql2014'
$dbname = 'AdventureWorks_DIFF'
$dbname_source = 'AdventureWorks'
$datafolder = 'D:\SQL2014\DATABASES'
$logfolder = 'D:\SQL2014\DATABASES'
$filter = $dbname_source + '_backup*.DIF'
$url = 'D:\SQL2014\BACKUPS'
$bklist = GetLatestBackup $url $filter
Write-Host 'list of backups'
foreach ($x in $bklist)
{	
	$x.Name
}
$backupfile = $URL + '\' + $bklist[-1].Name
Write-Host 'latest backup is'
$backupfile
$sql = RestoreDatabase $server $backupfile $dbname $logfolder $datafolder $restore_options
$sql
#>
#TEST SECTION OF RESTORE DIFFERENTIAL - END


<#
# TEST SECTION OF RestoreLogs START
#	function RestoreLogs ($dbname, $sourcedb, $bkfolder, $restore_options)
#	
#	Builds the sql for the restore of all the logs with desired recovery option
#	If there are no logs and the recovery is RECOVERY, it will set the database as recovered
#	
#	$restore_options['restore_type'] 	=> DIFFERENTIAL DATABASE LOG
#	$restore_options['recovery'] 		=> RECOVERY  NORECOVERY
#	$restore_options['replace'] 		=> $True $False
#	$restore_options['backup_mask']		=> _backup_20*.BAK
#	$restore_options['log_mask']		=> _backup_20*.TRN'
#	$restore_options['dif_mask']		=> _backup_20*.DIF'

$restore_options = @{}
$restore_options['recovery'] = 'RECOVERY'
$restore_options['backup_mask'] = '_backup_20*.BAK'
$restore_options['log_mask']    = '_backup_20*.TRN'

$dbname='DatabaseName'
$sourcedb='DatabaseName'
$bkfolder='\\SQLSERVERNAME\sqlbackups'

$sql = RestoreLogs $dbname $sourcedb $bkfolder $restore_options
$sql

Sample output
RESTORE LOG DatabaseName FROM DISK = '\\sqlbackups\DatabaseName_backup_2015_06_16_020003_3640768.trn' WITH NORECOVERY
RESTORE LOG DatabaseName FROM DISK = '\\\sqlbackups\DatabaseName_backup_2015_06_16_040012_9528391.trn' WITH NORECOVERY
RESTORE LOG DatabaseName FROM DISK = '\\\sqlbackups\DatabaseName_backup_2015_06_16_060001_3285453.trn' WITH NORECOVERY
RESTORE LOG DatabaseName FROM DISK = '\\\sqlbackups\DatabaseName_backup_2015_06_16_080001_7608005.trn' WITH NORECOVERY
RESTORE LOG DatabaseName FROM DISK = '\\\sqlbackups\DatabaseName_backup_2015_06_16_100002_2973865.trn' WITH NORECOVERY
RESTORE DATABASE DatabaseName WITH RECOVERY

#TEST SECTION OF RestoreLogs END
#>

<# TEST OF BACKUP - start
#BackupDatabase($dbname, $backupfile, $backup_options)
$options = @{}
$options['compression'] = $False
$options['backup_type'] = 'DATABASE'
$sql = BackupDatabase 'DATABASENAME' 'D:\backups\Database_backup.BAK' $options
$sql
$options['backup_type'] = 'DIFFERENTIAL'
$sql = BackupDatabase 'DATABASENAME' 'D:\backups\Database_backup.DIF' $options
$sql
$options['backup_type'] = 'LOG'
$sql = BackupDatabase 'DATABASENAME' 'D:\backups\Database_backup.TRN' $options
$sql
#>


<# TEST OF DatedString

$d = DatedString
$d
#Output
#2015_06_19_150545_0000000
#>




