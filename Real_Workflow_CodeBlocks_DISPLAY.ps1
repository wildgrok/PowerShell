# Real_Workflow_CodeBlocks.ps1 - Used from Real_Workflow.ps1
# Here we put mre specific code blocks that use other blocks

$RestoreDatabase = # Restores the database from given backup file to given data and log folders
{
	param ($server,$backupfile, $dbname1, $dbname2, $logfolder, $datafolder, $restore_options)
 . C:\WORKFLOWS\Real_Workflow_CodeBlocks1.ps1	# imports ExecuteSQL, GetLatestBackup, GetBackupinfo
 # code building the sql for the db restore
}


$RestoreLogs = # Restores the log from given single backup file log or folder with log backups
{
  param ($server,$backupfile, $dbname1, $dbname2, $restore_options)
  # Remember the magic: 
   . C:\WORKFLOWS\Real_Workflow_CodeBlocks1.ps1	# Imports ExecuteSql
  # code building the sql for the log restore   
}

