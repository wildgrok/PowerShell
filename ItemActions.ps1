#Version in workstation



function ReadActions($file, $set)
<#
	Returns a list of actions from the file for the passed set 
	A set is a collection of actions
	Sample file with two sets RESTORE SYSTEST and RESTORE SYSTEST WITH LOGS:
	
	RESTORE SYSTEST
    	SQL|RESTORE DATABASE RECOVERY
	RESTORE SYSTEST WITH LOGS
		SQL|RESTORE DATABASE NORECOVERY
		SQL|RESTORE LOG NORECOVERY
		SQL|SET DATABASE RECOVERY
		
	Set actions start with a tab or spaces (indented)
	Set names have no indentation (RESTORE SYSTEST, RESTORE SYSTEST WITH LOGS)
	
	If the set name is duplicated below in the file the other sets are discarded
	Only the first one is used
#>
{
	$list = @()
	$capture = $False
	$already_read = $False
	$z = Get-Content $file
	foreach ($x in $z)
	{
		$m = $x.TrimEnd()
		if ($m -eq '' -or $m[0] -eq '#') 
		{
			; #skip this blank or commented line and continue
		}
		else
		{
			if (($m -eq $set) -and ($already_read -eq $False))
			{
				$capture = $True
				$already_read = $True
			}
			if (($m[0] -ne [char]32) -and ($m[0] -ne [char]9) -and ($m -ne $set))
			{$capture = $False}
			if (($m[0] -eq [char]32) -or ($m[0] -eq [char]9)  -and ($capture -eq $True)) # this means line is part of a set of tasks				
			{ $list = $list + $m.Trim()}
		}	
	}
	$list
}

function LogSQL($item, $sql)
{
	if ($item['DBNAME2'] -and $item['DBNAME1']) { $db = $item['DBNAME2']}
	else { $db = $item['DBNAME1']}
	
	$CR = [char]13 + [char]10
	$s = '/* ------------------------------------------------------------'    + $CR
	$s = $s + '--SQL Server: ' + $item['SERVERNAME'] 	+ $CR 
	$s = $s + '--Database: ' + $db		+ $CR 
	$s = $s + '--Date: ' + (Get-Date).ToString()		+ $CR + $CR
	$s = $s + $sql 									+ $CR 
	$s = $s + ' -------------------------------------------------------------- */' + $CR 
	$global:SQLSTORAGESTRING = $global:SQLSTORAGESTRING + $s
}


function SelectAction ($item)
{
<#
	Depending on the value of the ACTIONS CSV column a task is executed
	SQL scripts are logged
#>
	# common for all
	$restore_options = @{}
	$restore_options['backup_mask']		= '*.BAK'
	$restore_options['log_mask']		= '*.TRN'
	$restore_options['dif_mask']		= '*.DIF'
	$restore_options['replace'] = $True
	
	$backup_options = @{}
	#$backup_options['backup_type'] = '' 				#FULL LOG DIFFERENTIAL
	$backup_options['compression'] = $False 			#$TRUE $FALSE
	$backup_options['filename'] = 'DATED'				#SIMPLE DATED
	
	
	
	$action_list = ReadActions $global:ACTIONSFILE $item['ACTIONS']
	foreach ($k in $action_list)
	{
		switch($k)
		{
			# -----Restores-------------------------------------------
			'SQL|RESTORE DATABASE RECOVERY'
			{				
				$restore_options['restore_type'] = 'DATABASE'
				$restore_options['recovery'] = 'RECOVERY'
				$sArray = Action_RestoreDatabase $item $restore_options				
			}
			'SQL|RESTORE DATABASE NORECOVERY'
			{				
				$restore_options['restore_type'] = 'DATABASE'
				$restore_options['recovery'] = 'NORECOVERY'
				$sArray = Action_RestoreDatabase $item $restore_options
			}			
			'SQL|RESTORE DIFFERENTIAL RECOVERY'
			{				
				$restore_options['restore_type'] = 'DIFFERENTIAL'
				$restore_options['recovery'] = 'RECOVERY'
				$sArray = Action_RestoreDatabase $item $restore_options
			}
			'SQL|RESTORE DIFFERENTIAL NORECOVERY'
			{				
				$restore_options['restore_type'] = 'DIFFERENTIAL'
				$restore_options['recovery'] = 'NORECOVERY'
				$sArray = Action_RestoreDatabase $item $restore_options
			}
			'SQL|RESTORE LOG RECOVERY'
			{				
				$restore_options['restore_type'] = 'LOG'
				$restore_options['recovery'] = 'RECOVERY'
				$sArray = Action_RestoreDatabase $item $restore_options
			}			
			'SQL|RESTORE LOG NORECOVERY'
			{				
				$restore_options['restore_type'] = 'LOG'
				$restore_options['recovery'] = 'NORECOVERY'
				$sArray = Action_RestoreDatabase $item $restore_options
			}			
			
			# --------Backup-----------------------------------------
			'SQL|BACKUP DATABASE FULL'
			{
				$backup_options['compression'] = $False 			
				$backup_options['filename'] = 'DATED'	
				$backup_options['backup_type'] = 'DATABASE'
				$sArray = Action_BackupDatabase $item $backup_options
			}			
			'SQL|BACKUP DATABASE DIFFERENTIAL'
			{
				$backup_options['compression'] = $False 			
				$backup_options['filename'] = 'DATED'	
				$backup_options['backup_type'] = 'DIF'				
				$sArray = Action_BackupDatabase $item $backup_options
			}
			'SQL|BACKUP DATABASE LOG'
			{	
				$backup_options['compression'] = $False 			
				$backup_options['filename'] = 'DATED'	
				$backup_options['backup_type'] = 'LOG'				
				$sArray = Action_BackupDatabase $item $backup_options
			}						
			# ---------Misc SQL tasks--------------------------------
			'SQL|SET DATABASE RECOVERY'
			{
				$server = $item['SERVERNAME']
				$dbname = $item['DBNAME2']
				$s = 'RESTORE DATABASE ' + $dbname + ' WITH RECOVERY' + [char]13 + [char]10
				Invoke-Sqlcmd3 $server  $s	
			}
			'SQL|SET SA DBOWNER'
			{
				$server = $item['SERVERNAME']
				$dbname = $item['DBNAME2']
				$s = "USE [" + $dbname + "] EXEC dbo.sp_changedbowner @loginame = N'sa', @map = false " + [char]13 + [char]10
				Invoke-Sqlcmd3 $server  $s	
			}
			'SQL|SET SIMPLE MODE'
			{
				$server = $item['SERVERNAME']
				$dbname = $item['DBNAME2']
				$s = "ALTER DATABASE [" + $dbname + "] SET RECOVERY SIMPLE WITH NO_WAIT " + [char]13 + [char]10
				Invoke-Sqlcmd3 $server  $s	
			}
			'SQL|SHRINK LOG'
			{
				$server = $item['SERVERNAME']
				$dbname = $item['DBNAME2']
				$s = 'declare @logfilename varchar(200) select @logfilename = name  from sysfiles where groupid = 0 '
				$s += 'DBCC SHRINKFILE (@logfilename , 0, TRUNCATEONLY) '
				$s += 'USE [' + $dbname + '] ' + $s
				Invoke-Sqlcmd3 $server  $s	
			}
			'SQL|SYNC LOGINS'
			{
				$server = $item['SERVERNAME']
				$dbname = $item['DBNAME2']
				SyncLogins $server $dbname
			}	
			
		} 	# end of switch
		if ($s)
		{
			LogSQL $item $s
			$s = ''
		}
	} 		# end of $action_list loop
}			# end of SelectAction function


function Action_RestoreDatabase($item, $restore_options)
{
<#
	Does all restores for the item (full, log, dif)
	Logging SQL is included (no need to add in calling function)
	
	
	$restore_options['backup_mask']		=> _backup_20*.BAK
	$restore_options['log_mask']		=> _backup_20*.TRN'
	$restore_options['dif_mask']		=> _backup_20*.DIF'
#>

	$server = $item['SERVERNAME']
	$dbname2 = $item['DBNAME2']
	$dbname1 = $item['DBNAME1']
	$datafolder = $item['DATAFOLDER']
	$logfolder = $item['LOGFOLDER']
	switch ($restore_options['restore_type'])
	{
		'LOG'
		{
			$filter = $restore_options['log_mask']
		}
		'DATABASE'
		{
			$filter = $restore_options['backup_mask']
		}
		'DIFFERENTIAL'
		{
			$filter = $restore_options['dif_mask']
		}		
	}
	# default is filter for backups uses source database name
	$filter = $dbname1 + '_' + $filter
	
	$url = $item['SOURCESERVER']
	$bklist = GetLatestBackup $url $filter
	$backupfile = $URL + '\' + $bklist[-1]
	if ($restore_options['restore_type'] -eq 'LOG')
	{
		$sql = RestoreLogs $dbname2 $dbname1 $url $restore_options
	}
	else
	{
		$sql = RestoreDatabase $server $backupfile $dbname2 $logfolder $datafolder $restore_options
		
	}
	Invoke-Sqlcmd3 $server  $sql
	LogSQL $item $sql
}


function Action_BackupDatabase($item, $backup_options)
{
<#
	Does all backups for the item (full, log, dif)
	Logging SQL is included (no need to add in calling function)
	
	$backup_options = @{}
	$backup_options['backup_type'] => DATABASE LOG DIFFERENTIAL
	$backup_options['compression'] => $TRUE $FALSE
	$backup_options['filename'] => SIMPLE DATED
	
#>

	$server = $item['SERVERNAME']
	$dbname1 = $item['DBNAME1']
	$dt = DatedString
	
	switch ($backup_options['backup_type'])
	{
		'LOG'
		{
			if ($backup_options['filename'] -eq 'SIMPLE')
			{
				$BKFILE = $dbname1 + '.TRN'
			}
			if ($backup_options['filename'] -eq 'DATED')
			{
				$BKFILE = $dbname1 + '_' + $dt + '.TRN'
			}
		}
		'DATABASE'
		{
			if ($backup_options['filename'] -eq 'SIMPLE')
			{
				$BKFILE = $dbname1 + '.BAK'
			}
			if ($backup_options['filename'] -eq 'DATED')
			{
				$BKFILE = $dbname1 + '_' + $dt + '.BAK'
			}
		}
		'DIFFERENTIAL'
		{
			if ($backup_options['filename'] -eq 'SIMPLE')
			{
				$BKFILE = $dbname1 + '.DIF'
			}
			if ($backup_options['filename'] -eq 'DATED')
			{
				$BKFILE = $dbname1 + '_' + $dt + '.DIF'
			}
		}		
	}
	
	$url = $item['SOURCESERVER']
	$BKFILE = $URL + '\' + $BKFILE
	$sql = BackupDatabase $dbname1 $BKFILE $backup_options
	Invoke-Sqlcmd3 $server  $sql
	LogSQL $item $sql
}

function ListDrives($Servername)
{
    ForEach-Object `
    {
        get-wmiobject -computername $Servername win32_logicaldisk `
        | select-object systemname, deviceID, Size, Freespace, DriveType `
    }
}
	
	
function GetDiskSpace ($machinename)
{
	$PERCENTFREE = 20
	$fullreport = "Server | Drive | TotalGB | FreeGB | Free% : " + [char]10
	$erroractionpreference = "SilentlyContinue"
    $a = ListDrives($machinename)
	$outmessage = ''
    foreach ($k in $a)
    {
        if ($k.DriveType -eq 3 -and $k.size -ne $null)
        {
            #Section for the lowspace report ---------------------
            $percent =(([long] $k.freespace) / ([long] $k.size)) * 100
			$percent = [int]$percent
			$j = $k.systemname + "|" + $k.deviceid + "|" + [int]($k.size/1GB) + "|" + [int]($k.freespace/1GB) + "|" + $percent

            #Section for whole report-------------------------------
            $fullreport = $fullreport + $j + [char]10 + [char]13
        }
    }
	return $fullreport
}
# --------------------End of functions----------------------------------




# --------------------PROGRAM START-------------------------------------

Set-Location D:\Users\jorgebe\Documents\powershell
. .\CONFIG.ps1
. .\SQLSMO.ps1

# Get action line passed from DBLIST
$lineitem = $args[0]

#Incoming line from csv file: SERVERNAME,DBNAME1,SOURCESERVER,DATAFOLDER,LOGFOLDER,DBNAME2,ACTIONS,ENABLED
$item = @{}

if ($lineitem -gt '')
{
	# this is to fix items that may contain a comma, like server name with port "XXSERVER,3655"
	$line = $lineitem -split ',(?=(?:[^"]|"[^"]*")*$)' 
	
	# we only use lines enabled with Y in last column and not commented with #
	if ($line[7].ToUpper().Trim() -eq 'Y' -and $line[0][0] -ne '#')
	{
		$item['SERVERNAME'] = $line[0]
		$item['DBNAME1'] = $line[1]
		$item['SOURCESERVER'] = $line[2]
		$item['DATAFOLDER'] = $line[3]
		$item['LOGFOLDER'] = $line[4]
		$item['DBNAME2'] = $line[5]
		$item['ACTIONS'] = $line[6]		
	}
	else
	{
		return
	}
}



# Process the line passed
SelectAction ($item)


# Will use it to allow writing to log file from the multiple threads
$mtx = New-Object System.Threading.Mutex($false, "LogMutex") | Out-Null
$mtx.WaitOne()
Add-Content -Path $global:LOGSQLFILE -Value $global:SQLSTORAGESTRING
$mtx.ReleaseMutex()

