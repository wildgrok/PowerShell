#Jobs_CodeBlocks.ps1
#Used from Jobs_Sample.ps1

#Based on Chad Millers Invoke-SqlCmd3
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

$GetBackupInfo = 
{
  param ($server, $backupfile)
  <#
      Sample use:
      $bkfile = '\\servername\PRODUCTIONBACKUPS\DBNAME_backup_2015_05_11_000029_6076771.bak'
      $d = GetBackupInfo $server $bkfile
      foreach ($x in $d)
      {
      foreach ($y in $x.sqlfilelist)	{$y}
      }

      LogicalName          : DBNAME_Data
      PhysicalName         : G:\SQLDATA\DBNAME_data.mdf
      Type                 : D
      FileGroupName        : PRIMARY
      Size                 : 52428800
      ...
      LogicalName          : DBNAME_Log
      PhysicalName         : F:\SQLLOGS\DBNAME_Log.ldf
      Type                 : L
      FileGroupName        : 
      Size                 : 14417920
      ...
      Using properties:
      $d.sqlfilelist.logicalname gives
      DBNAME_Data
      DBNAME_Log
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
    Filter is case sensitive
    $filter = 'DatabaseName_*.bak'
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
    $url = '\\servername\sqlbackups\SQLBackupUser'
    $filter='DBNAME_*.bak'
    $lst = (Invoke-Command -ScriptBlock $GetLatestBackup -ArgumentList ($url, $filter))
    $lst
#>

$GetBackups = 
<#
    Brings list of backups based on filter
#>
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

$RestoreDatabase = 
{
	param ($server,$backupfile, $dbname1, $dbname2, $logfolder, $datafolder, $restore_options)
. C:\WORKFLOWS\Jobs_CodeBlocks.ps1	
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
	
	# if passing a folder get latest backup on it, if file, use it
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
		$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s1, "master"))
	}	
	
	$s = $s + [char]13 + [char]10 + $s1
	return $s
}


$RestoreLogs = 
{
  param ($server,$backupfile, $dbname1, $dbname2, $restore_options)
  # Remember the magic: 
  . C:\WORKFLOWS\Jobs_CodeBlocks.ps1	
  <#
      Restores the log from given single backup file log or folder with log backups
      Options for $restore_options['restore_type'] are:
      DATABASE
      DIFFERENTIAL
      LOG
      options for $restore_options['recovery'] are:
      RECOVERY
      NORECOVERY	
      Sample sql built
      RESTORE LOG [ZZZ_Deleteme_4] FROM  DISK = '\\SERVERNAME\SQLBACKUPS\ZZZ_deleteme_1_1.trn' 
      WITH  FILE = 1,  NORECOVERY,  NOUNLOAD;
      RESTORE LOG [ZZZ_Deleteme_4] FROM  DISK = '\\SERVERNAME\SQLBACKUPS\ZZZ_deleteme_1_2.trn' 
      WITH  FILE = 1,  NOUNLOAD;
     		
  #> 
	
  # if passing a single log backup file:
  $s = '' 
  if ($backupfile.Trim().EndsWith('.trn') -eq $True) #single backup passed
  {
    # Restoring from file
    $backupfile		                                                     
    $s = $s + ' RESTORE LOG [' + $dbname2  + '] FROM  DISK = ' + [char]39 + $backupfile + [char]39
    $s = $s + ' WITH FILE = 1, NORECOVERY,  NOUNLOAD;'
    if ($restore_options['recovery'] -eq 'RECOVERY')
    {
      $s = $s + ' RESTORE DATABASE [' + $dbname2 + '] WITH RECOVERY;'
    }
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $s, "master")
    return $s
  }
  else #we are restoring from network folder with several log backups
  {
    #		Get list of backups sorted by time DO NOT SORT BY NAME!!!
    #		Source folder is  $backupfile
    #		Sample $backupfile = '\\servername\BACKUPS'
    $bklist = Get-ChildItem  $backupfile  | Sort-Object -Property LastWriteTime -Descending
    $bklist2 = ""
    $filter = $dbname1 + '_*.trn'
    foreach ($k in $bklist)
    {
      if ($k.Name -like $filter)
      {
        $bklist2 = $k.Name  + "|" + $bklist2
      }
    }
    #removing last character "|"
    $bklist2 = $bklist2.Substring(0,$bklist2.Length-1)
    #Ok get a list sorted by date
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
    return $s
  }	
}
