#SQLSMO2.ps1
#version in work PC
#Based on SQLSMO.ps1, adds jobs
#Created 6/3/2019
#Last updated:
#6/14/2019: several fixes after adding delay, moved back scriptblocks to SQLSMO2_CodeBlocks.ps1
#6/4/2019: converted RestoreDatabase to scriptblock

#---------------GLOBALS------------------------------------------
#$sqlfilelist =          'SET NOCOUNT ON RESTORE FILELISTONLY FROM DISK = ' + [char]39 + $backupfile + [char]39 
#$sqlfileheader =        'SET NOCOUNT ON RESTORE HEADERONLY FROM DISK = ' + [char]39  + $backupfile + [char]39 
#$sqlxp_fixeddrives =    'SET NOCOUNT ON EXEC master..xp_fixeddrives'
#$sqlsphelpdb =          'SET NOCOUNT ON select name, physical_name, (size * 8/1000) as size, data_space_id from ['+ $currdb + '].sys.database_files'

#[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") 			| Out-Null
#[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") 	| Out-Null
#[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") 		| Out-Null
#[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") 				| Out-Null

#---------------FUNCTIONS---------------------------------------

function Invoke-Sqlcmd4 ($ServerInstance,$Query)
<#
	Used in multithreading calls (performs better than Invoke-Sqlcmd3 in this case)
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


#scriptblock version
$RestoreDatabase = 
{
	param ($server,$backupfile, $dbname, $logfolder, $datafolder, $restore_options)
. C:\Users\jorgebe\Documents\powershell\SQLSMO2_CodeBlocks.ps1	
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
		$bkfile = (Invoke-Command -ScriptBlock $GetLatestBackup -ArgumentList ($backupfile))
		$backupfile2 = $backupfile + '\' + $bkfile
		$backupfile2		
	}
	
	$dict_backup = (Invoke-Command -ScriptBlock $GetBackupInfo -ArgumentList ($server, $backupfile2, "master"))

	# Start building the restore SQL
    $s = 'USE MASTER RESTORE DATABASE [' + $dbname + '] FROM DISK =' + [char]39 + $backupfile2 + [char]39 + ' WITH '
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
			$file_renamed = $dbname + '_' + $suffix + $ext
			$s = $s + ' MOVE ' + [char]39 + $x.logicalname + [char]39 + ' TO ' + [char]39 + $logfolder + '\' + $file_renamed + [char]39 + ', '
		}
        else  # any other type (D,F,S) we put in the Data folder
		{
            $suffix = 'Data'
			$file_renamed = $dbname + '_' + $suffix + $suffix2 + $ext
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
    $s1 = $s1 + ' FROM master..sysprocesses WHERE dbid = db_id(' + [char]39 + $dbname + [char]39 + ') '
    $s1 = $s1 + ' EXEC(@kill); '
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s1, "master"))
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s, "master"))
	if ($restore_options['recovery'] -eq 'RECOVERY')
	{
		$s1 = 'ALTER AUTHORIZATION ON DATABASE::[' + $dbname + '] TO [sa]' +  [char]13 + [char]10
		$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s1, $dbname))
	}	
	
	$s = $s + [char]13 + [char]10 + $s1
	return $s
}

<# to test
$server = 'CCLUATSPSDB1'
$backupfile = '\\CCLUATSPSDB1\ProductionBackup\CCL_CORP_DOMAIN_DATA_STAGING_backup_2019_06_03_020001_1594505.bak'
$dbname = 'CCL_CORP_DOMAIN_DATA_STAGING'
$logfolder = 'E:\SQLLOGS'
$datafolder = 'G:\SQLDATA'
$restore_options = @{}
$restore_options['restore_type'] = 'DATABASE'
$restore_options['recovery'] = 'RECOVERY'
$restore_options['replace'] = $True
$s = (Invoke-Command -ScriptBlock $RestoreDatabase -ArgumentList ($server,$backupfile, $dbname, $logfolder, $datafolder, $restore_options))
$s
#>

#$Run_Task = 
#{
#	param($line)
#	$a = $line.Split('|')
#	$SOURCESERVER = $a[0]
#	$BACKUPFILE = $a[1]
#	$SOURCEDB = $a[2]
#	$DESTSERVER = $a[3]
#	$DATAFOLDER = $a[4]
#	$LOGFOLDER = $a[5]
#	$DESTDB = $a[6]
#	$ACTIONS = $a[7]
#	$ENABLED = $a[8]
#	$restore_options = @{}
#	if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_RECOVERY')
#	{		
#		$restore_options['restore_type'] = 'DATABASE'
#		$restore_options['recovery'] = 'RECOVERY'
#		$restore_options['replace'] = $True	
#	}	
#}

#work in progress
$RestoreLogs = 
{
	param ($server,$backupfile, $dbname, $restore_options)
	#param ($server,$backupfile, $dbname, $logfolder, $datafolder, $restore_options)
. C:\Users\jorgebe\Documents\powershell\SQLSMO2_CodeBlocks.ps1	
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
	if ($restore_options['restore_type'] -ne 'LOG') { return }	
	
	# if passing a folder get latest backup on it
	if ($backupfile -like '*.trn') #single backup passed
	{
		"Restoring from file"
		$backupfile
	}
	else #we are restoring from network folder with several backups
	{
#		Get list of backups sorted by time
#		"Source folder is " $backupfile
		$bklist = Get-ChildItem  $backupfile  | Sort-Object -Property LastWriteTime -Descending
		$bklist2 = ""
		$filter = '*.trn'
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
	}
	
	# Start building the restore SQL
	$s = ''
	foreach ($k in $lst3)
	{
		$s = $s + " RESTORE LOG [" + $dbname  + "] FROM  DISK = '" + $backupfile + '\' + $k + "'"
		$s = $s + " WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  STATS = 10;" +  [char]13 + [char]10
	}	
	if ($restore_options['recovery'] -eq 'RECOVERY')
	{
		$s = $s + ' RESTORE DATABASE ' + $dbname + ' WITH RECOVERY;' +  [char]13 + [char]10

	}
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s, "master"))
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

#WORKING HERE ADDING JOBS

Set-Location C:\Users\jorgebe\Documents\powershell
#. C:\Users\jorgebe\Documents\powershell\SQLSMO2_CodeBlocks.ps1

$listofservers = Get-Content -Path 'DBLIST_ACTIONS_SQLSMO.TXT'
$CONCURRENCY = 10
#$listofservers

"Killing existing jobs . . ."
Get-Job | Remove-Job -Force
"Done."
" "

$cnt = 0
foreach ($k in $listofservers)
{
	$a = $k.Split('|')
	if ($cnt -gt 0)
	{
	#	$a
		$SOURCESERVER = $a[0]
		$BACKUPFILE = $a[1]
		$SOURCEDB = $a[2]
		$DESTSERVER = $a[3]
		$DATAFOLDER = $a[4]
		$LOGFOLDER = $a[5]
		$DESTDB = $a[6]
		$ACTIONS = $a[7]
		$ENABLED = $a[8]
		
#		$SOURCESERVER
#		$BACKUPFILE 
#		$SOURCEDB 
#		$DESTSERVER 
#		$DATAFOLDER 
#		$LOGFOLDER 
#		$DESTDB 
#		$ACTIONS
#		$ENABLED
			
		$restore_options = @{}
#		$restore_options['restore_type'] = 'DATABASE'
#		$restore_options['recovery'] = 'RECOVERY'
#		$restore_options['replace'] = $True	
		
#		$null = (Invoke-Command -ScriptBlock $Run_RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options))
#		$s = (Invoke-Command -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options))
#		$s
#		
		$running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
		if ($running.Count -le $CONCURRENCY -and $ENABLED -eq 'Y') 
		{	
			if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_RECOVERY')
			{		
				$restore_options['restore_type'] = 'DATABASE'
				$restore_options['recovery'] = 'RECOVERY'
				$restore_options['replace'] = $True	
				Start-Job -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options) 	#| Out-Null				
			}
			
			if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_NORECOVERY')
			{		
				$restore_options['restore_type'] = 'DATABASE'
				$restore_options['recovery'] = 'NORECOVERY'
				$restore_options['replace'] = $True	
				Start-Job -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options) 	#| Out-Null				
			}
			
			#new 6/19/2019
			if ($ACTIONS -eq 'RESTORE_LOGS_WITH_NORECOVERY')
			{		
				$restore_options['restore_type'] = 'LOG'
				$restore_options['recovery'] = 'NORECOVERY'
				$restore_options['replace'] = $True	
				Start-Job -ScriptBlock $RestoreLogs -ArgumentList ($DESTSERVER,$BACKUPFILE, $DESTDB, $restore_options) 	#| Out-Null				
			}
			
			#new 6/20/2019
			if ($ACTIONS -eq 'RESTORE_LOGS_WITH_RECOVERY')
			{		
				$restore_options['restore_type'] = 'LOG'
				$restore_options['recovery'] = 'RECOVERY'
				$restore_options['replace'] = $True					
				Start-Job -ScriptBlock $RestoreLogs -ArgumentList ($DESTSERVER,$BACKUPFILE, $DESTDB, $restore_options) 	#| Out-Null				
			}
			
			
			
#			Start-Job -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options) 	#| Out-Null				
#			Start-Sleep -s 5
		}
		else
		{ 
			$running | Wait-Job #| Out-Null
		}		
	}
	$cnt++
}
Get-Job | Receive-Job #| Out-Null
















#Write-Host "called from SQLSMO"

#----------------------Program-----------------------------------------------------


#Set-Location D:\Users\jorgebe\Documents\powershell

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

<# TEST OF INVOKE-SQLCMD5 START

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
Invoke-Sqlcmd5 $Server $Query

TEST OF INVOKE-SQLCMD5 END
#>


<# TEST OF INVOKE-SQLCMD5 START

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
Invoke-Sqlcmd2 -ServerInstance $Server -Query $Query
TEST OF INVOKE-SQLCMD2 END
#>





 
#TEST SECTION OF RESTORE DATABASE - START
<#
$restore_options = @{}
$restore_options['restore_type'] = 'DATABASE'
$restore_options['recovery'] = 'RECOVERY'
$restore_options['replace'] = $True
$server = "XXUATSQL3,3655"
$dbname = 'ssadserver'
$datafolder = 'F:\SQLDATA'
$logfolder = 'E:\SQLLOGS'
$filter = 'ssadserver_backup*.bak'
$url = '\\ccluatdtsdb5\ProductionBackup\BRSQL1_Backups'
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
$bkfolder='\\Ccluatdtsdb1\sqlbackups'

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




