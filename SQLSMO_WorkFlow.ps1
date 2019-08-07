#SQLSMO_WorkFlow.ps1
#version in work PC
#C:\Users\jorgebe\Documents\powershell\workflows
#Based on SQLSMO2.ps1 from C:\Users\jorgebe\Documents\powershell, changes the jobs to workflow parallel
#Uses SQLSMO_WorkFlow_CodeBlocks.ps1 to import (based on SQLSMO2_CodeBlocks.ps1 in C:\Users\jorgebe\Documents\powershell)
#Called from SQLSMO_WorkFlow.cmd
#Created 8/1/2019
#Last modified:
#8/2/2019: fixed typos in C:\Users\jorgebe\Documents\powershell\workflows
#8/2/2019: started changes to workflow parallel (not ready yet)

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





#=========================PROGRAM STARTS===========================================
#workflow Run-Workflow 
#{ # start of workflow
#InlineScript 
#{ 
#		param([string[]]$listofservers)
		
  #needed to import ExecuteSQL, GetBackupInfo, RestoreDatabase, RestoreLogs, GetLatestBackup
#. C:\Users\jorgebe\Documents\powershell\workflows\SQLSMO_Workflow_CodeBlocks.ps1	
	Set-Location C:\Users\jorgebe\Documents\powershell\workflows
	$listofservers = Get-Content -Path 'DBLIST_ACTIONS_SQLSMO.TXT'
	$CONCURRENCY = 5


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
		$SOURCESERVER = $a[0]
		$BACKUPFILE = $a[1]
		$SOURCEDB = $a[2]
		$DESTSERVER = $a[3]
		$DATAFOLDER = $a[4]
		$LOGFOLDER = $a[5]
		$DESTDB = $a[6]
		$ACTIONS = $a[7]
		$ENABLED = $a[8]
		
		$restore_options = @{}
				
		$running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
				
		if ($running.Count -le $CONCURRENCY -and $ENABLED -eq 'Y') 
		{	
			#test print, to be commented
			#in teh jobs version it works, does not in workflow
			$a
			#this is the workflow version
				
			
			if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_RECOVERY')
			{		
				$restore_options['restore_type'] = 'DATABASE'
				$restore_options['recovery'] = 'RECOVERY'
				$restore_options['replace'] = $True	
				Start-Job -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options) 	#| Out-Null				

			}
			
			if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_NORECOVERY')
			{	
				$restore_options['restore_type'] = 'DATABASE'
				$restore_options['recovery'] = 'NORECOVERY'
				$restore_options['replace'] = $True
				Start-Job -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options) 	#| Out-Null				

			}
			
			
      if ($ACTIONS -eq 'RESTORE_LOGS_WITH_NORECOVERY')
      {
        $restore_options['restore_type'] = 'LOG'
        $restore_options['recovery'] = 'NORECOVERY'
        $restore_options['replace'] = $True
        Start-Job -ScriptBlock $RestoreLogs -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $restore_options) 	#| Out-Null				

      }
			
			
      if ($ACTIONS -eq 'RESTORE_LOGS_WITH_RECOVERY')
      {		
        $restore_options['restore_type'] = 'LOG'
        $restore_options['recovery'] = 'RECOVERY'
        $restore_options['replace'] = $True
        Start-Job -ScriptBlock $RestoreLogs -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $restore_options) 	#| Out-Null				

      }
			
		}
		else
		{ 
			$running | Wait-Job #| Out-Null
		}		
	}
	$cnt++
}
Get-Job | Receive-Job #| Out-Null

#} #end of inlinescript
	
#little demo of the parallel use: executes in 60 seconds instead of 100 seconds	
#InlineScript 
#{ 
#	Write-Output "Started parallel process"	
#	Get-Date
#}	
#
#parallel
#{
#	Start-Sleep -s 60
#	Start-Sleep -s 30
#	Start-Sleep -s 10
#}
#	
#InlineScript 
#{ 
#	Write-Output "Completed parallel process"	
#	Get-Date
#}	

#} # end of workflow	
#Run-Workflow

#. C:\Users\jorgebe\Documents\powershell\workflows\SQLSMO_Workflow_CodeBlocks.ps1	
#Set-Location C:\Users\jorgebe\Documents\powershell\workflows
#
#$listofservers = Get-Content -Path 'DBLIST_ACTIONS_SQLSMO.TXT'
#$CONCURRENCY = 5

#Run-Workflow $listofservers


















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




