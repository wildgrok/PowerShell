#SQLSMO_WorkFlow.ps1
#version in work PC
#C:\Users\jorgebe\Documents\powershell\workflows
#Based on SQLSMO2.ps1 from C:\Users\jorgebe\Documents\powershell, changes the jobs to workflow parallel
#Uses SQLSMO_WorkFlow_CodeBlocks.ps1 to import (based on SQLSMO2_CodeBlocks.ps1 in C:\Users\jorgebe\Documents\powershell)
#Called from SQLSMO_WorkFlow.cmd
#Created 8/1/2019
#Last modified:
#8/7/2019 tested restoredabase and restorelogs using workflow (but with the jobs inside) ok
#8/7/2019 tested restorelogs (jobs version)
#8/2/2019: fixed typos in C:\Users\jorgebe\Documents\powershell\workflows
#8/2/2019: started changes to workflow parallel (not ready yet)



#=========================PROGRAM STARTS===========================================
workflow Run-Workflow 
{ # start of workflow
InlineScript 
{ 
#		param([string[]]$listofservers)
		
  #needed to import ExecuteSQL, GetBackupInfo, RestoreDatabase, RestoreLogs, GetLatestBackup
. C:\Users\jorgebe\Documents\powershell\workflows\SQLSMO_Workflow_CodeBlocks.ps1
	
	Set-Location C:\Users\jorgebe\Documents\powershell\workflows
	$listofservers = Get-Content -Path 'DBLIST_ACTIONS_SQLSMO.TXT'
	$CONCURRENCY = 5


#"Killing existing jobs . . ."
Get-Job | Remove-Job -Force
#"Done."
#" "


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
			#in the jobs version it works, does not in workflow
			#$a
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

} #end of inlinescript
	


} # end of workflow	
Run-Workflow

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




