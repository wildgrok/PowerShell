#param([string]$SQLSERVER,
#  [string]$newDBName,
#  [string]$backupFilePath,
#   [string]$datafolder,
#[string]$logfolder
#)

$SQLSERVER = $args[0]
$newDBName = $args[1]
$backupFilePath = $args[2]
$datafolder = $args[3]
$logfolder= $args[4]

$SQLSERVER
$newDBName
$backupFilePath
$datafolder
$logfolder


# Load assemblies
[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") #| Out-Null
[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") #| Out-Null
[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") #| Out-Null
#[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") #| Out-Null
[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.Smo.Server") #| Out-Null
#[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.Smo.Server") #| Out-Null

function RestoreDBSMO ($SQLSERVER, $newDBName, $backupFilePath, $datafolder, $logfolder)
{

        $DATESTRING = get-date -format yyyyMMdd

        # Create sql server object      
        $server = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Server $SQLSERVER
        
		# Update database properties and refresh the database:
		$server.killallprocesses($newDBName)
		
        # Create restore object and specify its settings
        $smoRestore = new-object("Microsoft.SqlServer.Management.Smo.Restore")
        $smoRestore.Database = $newDBName
        $smoRestore.NoRecovery = $false;
        $smoRestore.ReplaceDatabase = $true;
        $smoRestore.Action = "Database"

        # Create location to restore from
        $backupDevice = New-Object ("Microsoft.SqlServer.Management.Smo.BackupDeviceItem") ($backupFilePath, "File")
        $smoRestore.Devices.Add($backupDevice)

        # Get the file list from backup file
        $dbFileList = $smoRestore.ReadFileList($server)

		foreach ($x in $dbFileList)
		{
			if ($x.Type -eq 'D')
			{
				# Specify new data file (mdf)
				$smoRestoreDataFile = New-Object ("Microsoft.SqlServer.Management.Smo.RelocateFile")
      			$smoRestoreDataFile.PhysicalFileName =  $datafolder + '\' + $newDBName + '_' + $DATESTRING + '_' + $x.FileID.ToString() + "_Data.mdf"
				$smoRestoreDataFile.LogicalFileName = $x.LogicalName
				$smoRestore.RelocateFiles.Add($smoRestoreDataFile)
				Write-Host 'datafile:' $smoRestoreDataFile.PhysicalFileName  $x.LogicalName			
			}
			if($x.Type -eq 'L')
			{
				# Specify new log file (ldf)
				$smoRestoreLogFile = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile")
				$smoRestoreLogFile.PhysicalFileName = $logfolder + '\' + $newDBName + '_' + $DATESTRING + '_' + $x.FileID.ToString() +"_Log.ldf"
				$smoRestoreLogFile.LogicalFileName = $x.LogicalName
				$smoRestore.RelocateFiles.Add($smoRestoreLogFile)
				Write-Host 'logfile:' $smoRestoreLogFile.PhysicalFileName  $x.LogicalName
			}
		}

        # Restore the database
        $smoRestore.SqlRestore($server)		
		$db = $server.Databases[$newDBName]
#		$db.UserAccess = 'SINGLE';
		$db.SetOwner('sa', $TRUE)
#		$server.Databases[$newDBName].RecoveryModel = 'Simple';
		$db.RecoveryModel = [Microsoft.SqlServer.Management.Smo.RecoveryModel]::Simple
		$server.killallprocesses($newDBName)
		$db.Alter();
		$db.Refresh();

        "Database restore completed successfully"

} #end of function

#----Program starts here--------------------------

#$SQLSERVER = 'ccltstshrddb1\tstsql2'
#$newDBName = 'zzz_deleteme_XXXXXXX'
#$backupFilePath = '\\ccltstSHRDDB1\SQLBACKUPS\zzz_deleteme.bak'
#$datafolder = 'E:\SQLDATA\TSTSQL2'
#$logfolder = 'F:\SQLLOGS\TSTSQL2'

#RestoreDBSMO ($SQLSERVER, $newDBName, $backupFilePath, $datafolder, $logfolder)
RestoreDBSMO $SQLSERVER $newDBName $backupFilePath $datafolder $logfolder

#sample cmd file to call:
#powershell C:\Users\jorgebe\Documents\powershell\DBRestore\RestoreDB.ps1 ccltstshrddb1\tstsql2 zzz_deleteme_XXXXXXX \\ccltstSHRDDB1\SQLBACKUPS\zzz_deleteme.bak E:\SQLDATA\TSTSQL2 F:\SQLLOGS\TSTSQL2 



