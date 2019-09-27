#========================================================================
# DBATOOL_CodeBlocks2.ps1
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


$RestoreDatabase = 
{
	#$dbname1 is source db, $dbname2 is destination db
#	param ($server,$backupfile, $dbname1, $dbname2, $logfolder, $datafolder, $restore_options_recovery)
    param ($m)

    #needed to import ExecuteSQL, GetLatestBackup, GetBackupInfo used by RestoreDatabase
    . E:\powershell\DBATOOL_CodeBlocks.ps1	
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
    $a = $m.Split('|')
    
    $SOURCESERVER = $a[0]
	$BACKUPFILE = $a[1]
	$SOURCEDB = $a[2]
	$DESTSERVER = $a[3]
	$DATAFOLDER = $a[4]
	$LOGFOLDER = $a[5]
	$DESTDB = $a[6]
	$ACTIONS = $a[7]
	$ENABLED = $a[8]
    
    if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_RECOVERY')
	{		
		$restore_options_recovery = 'RECOVERY'
	}
     if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_NORECOVERY')
	{		
		$restore_options_recovery = 'NORECOVERY'
	}
    
    	
	# if passing a folder get latest backup on it
	if ($BACKUPFILE -like '*.bak')
	{
		"Restoring from file"
		$backupfile2 = $BACKUPFILE
		$BACKUPFILE
	}
	else
	{
		"Latest backup from folder"
		$filter = $SOURCEDB + '_*.bak'
		$bkfile = (Invoke-Command -ScriptBlock $GetLatestBackup -ArgumentList ($BACKUPFILE, $filter))
		$backupfile2 = $BACKUPFILE + '\' + $bkfile
		$backupfile2		
	}
	
	$dict_backup = (Invoke-Command -ScriptBlock $GetBackupInfo -ArgumentList ($SOURCESERVER, $backupfile2))

	# Start building the restore SQL
    $s = 'USE MASTER RESTORE DATABASE [' + $DESTDB  + '] FROM DISK =' + [char]39 + $backupfile2 + [char]39 + ' WITH '
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
			$file_renamed = $DESTDB + '_' + $suffix + $ext
			$s = $s + ' MOVE ' + [char]39 + $x.logicalname + [char]39 + ' TO ' + [char]39 + $logfolder + '\' + $file_renamed + [char]39 + ', '
		}
        else  # any other type (D,F,S) we put in the Data folder
		{
            $suffix = 'Data'
			$file_renamed = $DESTDB + '_' + $suffix + $suffix2 + $ext
			$s = $s + ' MOVE ' + [char]39 + $x.logicalname + [char]39 + ' TO ' + [char]39 + $datafolder + '\' + $file_renamed + [char]39 + ', '
		}       
        $filecount = $filecount + 1
	} # end of database file loop	
	
	$s = $s + ' NOUNLOAD, ' + $restore_options_recovery + ', STATS = 10'
#    if ($restore_options['replace'] -eq $True)
#	{
        $s = $s + ', REPLACE;' +  [char]13 + [char]10
#	}	
		
    # Doing the actual restore here. NEW: added code to kill connections in the same execution	
	$s1 =       'DECLARE @kill varchar(8000) = ' + [char]39 + [char]39 + ';'
    $s1 = $s1 + ' SELECT @kill = @kill + ' + [char]39 + 'kill ' + [char]39 + '  + CONVERT(varchar(5), spid) + ' + [char]39 + ';' + [char]39
    $s1 = $s1 + ' FROM master..sysprocesses WHERE dbid = db_id(' + [char]39 + $DESTDB + [char]39 + ') '
    $s1 = $s1 + ' EXEC(@kill); '
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SOURCESERVER, $s1, "master"))
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SOURCESERVER, $s, "master"))
	if ($restore_options_recovery -eq 'RECOVERY')
	{
		$s1 = 'ALTER AUTHORIZATION ON DATABASE::[' + $DESTDB + '] TO [sa]' +  [char]13 + [char]10
		$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SOURCESERVER, $s1, $DESTDB))
	}		
	$s = $s + [char]13 + [char]10 + $s1
	return $s
}



$RestoreLogs = 
{
#	param ($server,$backupfile, $dbname1,$dbname2, $restore_options)
	#param ($server,$backupfile, $dbname, $logfolder, $datafolder, $restore_options)
    # Is this needed? this is not calling extra codeblocks
    # YES IT IS NEEDED - it is calling ExecuteSQL!!!
#    . E:\powershell\DBATOOL_CodeBlocks.ps1	
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
    param ($m)

    #needed to import ExecuteSQL
    . E:\powershell\DBATOOL_CodeBlocks.ps1	
    
    $a = $m.Split('|')
    
    $SOURCESERVER = $a[0]
	$BACKUPFILE = $a[1]
	$SOURCEDB = $a[2]
	$DESTSERVER = $a[3]
	$DATAFOLDER = $a[4]
	$LOGFOLDER = $a[5]
	$DESTDB = $a[6]
	$ACTIONS = $a[7]
	$ENABLED = $a[8]
    
    if ($ACTIONS -eq 'RESTORE_LOGS_WITH_RECOVERY')
	{		
		$restore_options_recovery = 'RECOVERY'
	}
     if ($ACTIONS -eq 'RESTORE_LOGS_WITH_NORECOVERY')
	{		
		$restore_options_recovery = 'NORECOVERY'
	}
    
    
    
	# just checking 
#	if ($restore_options['restore_type'] -ne 'LOG') { return }	
	
	# if passing a folder get latest backup on it
	if ($BACKUPFILE -like '*.trn') #single backup passed
	{
		"Restoring from file"
		$BACKUPFILE
	}
	else #we are restoring from network folder with several backups
	{
#		Get list of backups sorted by time
#		"Source folder is " $backupfile
		$bklist = Get-ChildItem  $BACKUPFILE  | Sort-Object -Property LastWriteTime -Descending
		$bklist2 = ""
		$filter = $SOURCEDB + '_*.trn'
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
		$s = $s + " RESTORE LOG [" + $DESTDB  + "] FROM  DISK = '" + $BACKUPFILE + '\' + $k + "'"
		$s = $s + " WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  STATS = 10;" +  [char]13 + [char]10
	}	
	if ($restore_options_recovery -eq 'RECOVERY')
	{
		$s = $s + ' RESTORE DATABASE ' + $DESTDB + ' WITH RECOVERY;' +  [char]13 + [char]10

	}
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SOURCESERVER, $s, "master"))
	return $s
}



#NOT BEING USED
<#
$GetBackups = 
<#
	Brings list of backups based on filter
<#
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
#>










#$Run_RestoreDatabase = 
#{
#	param ($DESTSERVER,$BACKUPFILE, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options)
##. E:\powershell\DBATOOL_CodeBlocks.ps1	
#		
#	$s = (Invoke-Command -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options))
#	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($DESTSERVER,$s, "master"))	
#}