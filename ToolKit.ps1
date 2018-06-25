#collection of functions
#last updated 4/20/2018
#last updated 9/16/2014


function ExtractString ($String, $SearchStart, $SearchEnd)
{
    $startpos = $String.IndexOf($SearchStart)
#    $startpos
    $endpos   = $String.IndexOf($SearchEnd)
#    $endpos
    $result = $String.Substring($startpos + 1, $endpos - $startpos - 1).Trim()
    return $result
}
#$String="Jackpot_RGS:customer		|customer_id,signin_name,first_name,last_name,user_namecard_id"
#$SearchStart=":" #Will not be included in results
#$SearchEnd="|" #Will not be included in results
#$r = ExtractString $String $SearchStart $SearchEnd
#$r

function SaveDay($record)
{
#	$dt = get-date -format yyyyMMddHHmmss
	$dt = (get-date -format yyyyMMdd) + '.dat'
	Set-Content ($global:WORKFOLDER + '\' + $dt) $record

}


function RetrieveDay($dayfile)
{

	$lst2 = @()	
	$file = Get-Content $dayfile
	#$z = $lst.Split([char]10)
	foreach ($x in $file)
	{
		if ($x -gt "")
		{
			$lst2 += $x.Trim()
		}
	}
	#Write-Host 'length' $lst2.Length
	return $lst2
}
# to test
#$global:WORKFOLDER = 	'D:\Users\jorgebe\Documents\powershell'
#$r = RetrieveDay ($global:WORKFOLDER + '\20150513.dat')
#$r






function StringStuff
{
#PS C:\> [System.IO.Path]::GetFileNameWithoutExtension("Test Config.xlsx")
#Test Config
#PS H:\> [System.IO.Path]::GetExtension("Test Config.xlsx")
#.xlsx


}


function GetFolderLineCount($folder, $mask="")
{

	#$FILES_SOURCE = '\\cclprdsgsjobs1\BulkUploadCSVFiles\PublishRatesECOMM\20140915'

	#$filelist = Get-ChildItem $FILES_SOURCE -Filter 'cat_ecom*.csv' | Sort-Object Name 
	$filelist = Get-ChildItem $folder -Filter $mask | Sort-Object Name 
	$cnt = 0
	foreach ($x in $filelist)
	{	
		$file = $FILES_SOURCE + '\' + $x
		$b = Get-Content $file | Measure-Object –Line
		$cnt = $cnt + $b.Lines
		#(bcp tblCBICSiebelSync in $fixedfile -f g:\scripts\PERSON_PUSH\Person_Push.fmt -S CCLTSTSBLSQL1 -d SIEBELDB -T)
		#	(bcp tblCBICSiebelSync in $fixedfile -f $WORKFOLDER\Person_Push.fmt -S $SERVERNAME -d SIEBELDB -T)
		#bcp ccl_domain_data_staging.dbo.TB_PRICING_CATEGORY_STAG_ECOM_TroubleShoot in Cat_ECOM635463391066489776.csv -c -t"," -S ccltstecosqldb1\tstecosql7 -T
		#(bcp $TABLE in $file -c -t"," -S $SERVERNAME -T)
	}
	return $cnt
}
<#

#>
#GetFolderLineCount '\\cclprdsgsjobs1\BulkUploadCSVFiles\PublishRatesECOMM\20140915' 'cat_ecom*.csv'
#exit

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



function BackupAllDBs($SERVERNAME, $backupfolder, $option)
{
    
    $s = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SERVERNAME
    $s.Settings.BackupDirectory = $backupfolder
    $bkdir = $s.Settings.BackupDirectory    
    $dbs = $s.Databases
    $dbs | foreach-object {
        $db = $_
        if 
        (
            #uncomment to exclude system dbs
            #$db.IsSystemObject -eq $False -and     
            $db.IsMirroringEnabled -eq $False -and
            $db.Name -cnotlike '*_PV' -and
            $db.Name -ne 'tempdb'
        ) 
        {
            $dbname = $db.Name
            Write-Host $dbname
            $global:dbcount = $global:dbcount + 1
            $dt = get-date -format yyyyMMddHHmmss
            $dbbk = new-object ('Microsoft.SqlServer.Management.Smo.Backup')
            $dbbk.Initialize = $TRUE
            $dbbk.Action = 'Database'
            $dbbk.BackupSetDescription = "Full backup of " + $dbname
            $dbbk.BackupSetName = $dbname + " Backup"
            $dbbk.Database = $dbname
            $dbbk.MediaDescription = "Disk"
            $devicebkp = ''
            if ($option -eq $True)
            {
                $devicebkp = $bkdir + "\" + $dbname + "_db_" + $dt + ".bak"
            }
            else
            {
                $devicebkp = $bkdir + "\" + $dbname + ".bak"
            }
            $dbbk.Devices.AddDevice($devicebkp, 'File')
            $dbbk.SqlBackup($s)
            $global:dbdict[$dbname] = $devicebkp
        }   #end of if        
    }       #end of foreach-object
}           #end of function BackupAllDBs



function BackupDB($SERVERNAME, $database, $bkdir, $option)
{
    
    $s = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SERVERNAME
    $dbs = $s.Databases
    $dbs | foreach-object {
        $db = $_
        if 
        (
            #uncomment to exclude system dbs
            #$db.IsSystemObject -eq $False -and     
            $db.IsMirroringEnabled -eq $False -and
            $db.Name -cnotlike '*_PV' -and
            $db.Name -ne 'tempdb' -and
			$db.Name -eq $database
        ) 
        {
            $dbname = $db.Name
            Write-Host $dbname
            $global:dbcount = $global:dbcount + 1
#            $dt = get-date -format yyyyMMddHHmmss
			$dt = get-date -format yyyyMMdd
            $dbbk = new-object ('Microsoft.SqlServer.Management.Smo.Backup')
            $dbbk.Initialize = $TRUE
            $dbbk.Action = 'Database'
            $dbbk.BackupSetDescription = "Full backup of " + $dbname
            $dbbk.BackupSetName = $dbname + " Backup"
            $dbbk.Database = $dbname
            $dbbk.MediaDescription = "Disk"
            $devicebkp = ''
            if ($option -eq $True)
            {
				$devicebkp = $bkdir + "\" + $dbname + "_" + $dt + ".bak"
            }
            else
            {
                $devicebkp = $bkdir + "\" + $dbname + ".bak"
            }
            $dbbk.Devices.AddDevice($devicebkp, 'File')
            $dbbk.SqlBackup($s)
        }   #end of if        
    }       #end of foreach-object
}           #end of function BackupDB





function RestoreDBSMO ($SQLSERVER, $newDBName, $backupFilePath, $datafolder, $logfolder)
{

        $DATESTRING = get-date -format yyyyMMdd

        # Create sql server object
        $server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $SQLSERVER

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
#		Write-Host 'dbfilelist'
#		$dbFileList
#		exit
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


function ListDrives($Servername)
{
    ForEach-Object `
    {
        get-wmiobject -computername $Servername win32_logicaldisk `
        	| select-object systemname, deviceID, Size, Freespace, DriveType `
    }
}; #end of ListDrives function
	
	
function GetDiskSpace ($machinename)
{
	$PERCENTFREE = 20
	$fullreport = "Server | Drive | TotalGB | FreeGB | Free% : " + $z + [char]10
	$erroractionpreference = "SilentlyContinue"
    $a = ListDrives($machinename)
	$outmessage = ''
    foreach ($k in $a)
    {
        if ($k.DriveType -eq 3 -and $k.size -ne $null)
        {
            #Section for the lowspace report ---------------------
            $percent =(([long] $k.freespace) / ([long] $k.size)) * 100
            #$percent = [math]::round($percent, 0)
			$percent = [int]$percent
            $j = $k.systemname + "|" + $k.deviceid + "|" + [int]($k.size/1000000000) + "|" + [int]($k.freespace/1000000000) + "|" + $percent
            #Section for whole report-------------------------------
            $fullreport = $fullreport + $j + [char]10 + [char]13
        }
    }
		return $fullreport
}; #end of GetDiskSpace	


function SendMail ($report,$emails,$attacharray,$from,$subject)
{
    $smtpServer = "smtphost.carnival.com"
    $msg = new-object Net.Mail.MailMessage
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg.From = $from
    $emailarray = $emails.Split(';')
    if ($emailarray.Count -gt 0)
    {
        foreach ($c in $emailarray)
        {    
            $d = $c.Trim()
            $msg.To.Add($d)
        }
    }
    
    $attlist = $attacharray.Split(';')
    if ($attlist.Count -gt 0)
    {
        foreach ($c in $attlist)
        { 	
			if ($c -gt '')
			{
				$att = new-object Net.Mail.Attachment($c)
				$msg.Attachments.Add($att)
			}
		}
    }

    $msg.Subject = $subject;$msg.Body = $report;$smtp.Send($msg)
    
}

function Invoke-Sqlcmd3
{
    param(
    [string]$ServerInstance,
    [string]$Query
    )
	$QueryTimeout=30
    $conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Integrated Security=True"
	$conn.ConnectionString=$constring
    $conn.Open()
	if($conn)
    {
    	$cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
    	$cmd.CommandTimeout=$QueryTimeout
    	$ds=New-Object system.Data.DataSet
    	$da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
    	[void]$da.fill($ds)
    	$conn.Close()
    	$ds.Tables[0]
	}
}

#multiple recordsets version
function Invoke-Sqlcmd3-MR
{
    param(
    [string]$ServerInstance,
    [string]$Query
    )
	$QueryTimeout=30
    $conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Integrated Security=True"
	$conn.ConnectionString=$constring
    $conn.Open()
	if($conn)
    {
    	$cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
    	$cmd.CommandTimeout=$QueryTimeout
    	$ds=New-Object system.Data.DataSet
    	$da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
    	[void]$da.fill($ds)
    	$conn.Close()
		foreach ($x in $ds.Tables)
		{
    		$x
		}
	}
}


function CheckPing($server)
{
	$v = (ping $server -n 1)
	foreach ($k in $v)
	{
		if ($k.StartsWith("Reply"))
		{
			break
		}
		else
		{
			if ($k.StartsWith("Request timed out"))
			{
				return ""
			}		
		}
	}
	$l = $k.Replace('<', '=')
	$lst = $l.split('=')[2]
	if ($lst)
	{
		$r = $lst.Replace('ms TTL', '')
	}
	else
	{
		$r = ""
	}		
	return $r		
}


function ProcessServers($Serverlist)
{
	$outdict = @{}	
    $Computers = Get-Content -Path $Serverlist;
    foreach ($z in $Computers) 
    {
        if ($z -gt "" -and $z[0] -ne "#")
        {
			$ping = CheckPing($z)
			$outdict[$z] = [int]$ping
        }
    }
	return $outdict    
}
<#
#to test:
$SERVERLIST = 'D:\Users\jorgebe\Documents\powershell\ships_list.dat'
#fixes issue of extra blank line in ping response
#Usage notes:
Get-Date
Write-Host "Processing ships list " $SERVERLIST
$r = ProcessServers $SERVERLIST
$r.GetEnumerator() | Sort-Object Value
Write-Host "Process completed "
Get-Date
exit
#>

function GetAllActiveDirectoryUsers()
{
	$NumDays = 0
	#$LogDir = ".\User-Accounts.csv"

	$currentDate = [System.DateTime]::Now
	$currentDateUtc = $currentDate.ToUniversalTime()
	$lltstamplimit = $currentDateUtc.AddDays(- $NumDays)
	$lltIntLimit = $lltstampLimit.ToFileTime()
	$adobjroot = [adsi]''
	$objstalesearcher = New-Object System.DirectoryServices.DirectorySearcher($adobjroot)
	$objstalesearcher.PageSize = 1000
	$objstalesearcher.filter = "(&(objectCategory=person)(objectClass=user)(lastLogonTimeStamp<=" + $lltIntLimit + "))"

	$users = $objstalesearcher.findall() | select `
	@{e={$_.properties.cn};n='Display Name'},`
	@{e={$_.properties.samaccountname};n='Username'},`
	@{e={$_.properties.mail};n='Email Address'}, `
	@{e={$_.properties.givenname};n='First Name'}, `
	@{e={$_.properties.sn};n='Last Name'}, `
	@{e={[datetime]::FromFileTimeUtc([int64]$_.properties.lastlogontimestamp[0])};n='Last Logon'},`
	@{e={[string]$adspath=$_.properties.adspath;$account=[ADSI]$adspath;$account.psbase.invokeget('AccountDisabled')};n='Account Is Disabled'}

	#$users | Export-CSV -NoType $LogDir
	return $users
}


function ReadActions($file, $set)
<#
	Returns a list of actions from the file for the passed set 
	A set is a collection of actions
	Sample file with two sets RESTORE SYSTEST and RESTORE AG PRIMARY:
	
	RESTORE SYSTEST
    	RESTORE DATABASE RECOVERY
    	SET SA DBOWNER
    	SET SIMPLE MODE
    	SHRINK LOG
    	SYNC LOGINS
	RESTORE AG PRIMARY
    	RESTORE DATABASE NORECOVERY
    	RESTORE LOGS WITH RECOVERY
    	SYNC LOGINS
		
	Set actions start with a tab or spaces (indented)
	Set names have no indentation
	
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

function CountEnabledLines($file)
<#
	
#>
{
	$cnt = 0
	$z = Get-Content $file
	foreach ($x in $z)
	{
		$m = $x.TrimEnd()
		if ($m[-2] + $m[-1] -eq ',Y')
		{
			 $cnt = $cnt + 1
		}
	}
		
	return $cnt
}
#Set-Location 'D:\Users\jorgebe\Documents\powershell'
#$c = CountEnabledLines 'DBLIST_ACTIONS_LATEST.CSV'
#$c

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

<#
$s = "set nocount on select  b.name as 'table', a.name as 'column' from " + $CURRENT_DATABASE + ".sys.columns a "
$s = $s + "	join " + $CURRENT_DATABASE + ".sys.tables b on a.object_id = b.object_id join " + $CURRENT_DATABASE + ".sys.change_tracking_tables c on "
$SQL_tables_column = $s + "	c.object_id = b.object_id"
#>

function CreateDict
{
    $p = Invoke-Sqlcmd3 $CURRENT_SERVER $SQL_tables_column
    $dict = @{}
    $alreadyprocessed = ""
    foreach ($k in $p)
    {
        if ($k.table -ne $alreadyprocessed)
        {
            $alreadyprocessed = $k.table
            $cnt = 0
            foreach ($r in $p)
            {
                $cnt = 0
                if ($r.table -eq $k.table)
                {
                        if (!$dict[$k.table])
                        {
                            $dict[$k.table] = $r.column
                        }
                        else
                        {
                            $dict[$k.table] = $dict[$k.table] + "," + $r.column                    
                        }
                }
            }
        }   
    }
    return $dict
}

function Get_Webpage($url)
{
    #$url = 'https://support.microsoft.com/en-us/lifecycle/search/1044'
    $webResponse = Invoke-WebRequest $url
    return $webResponse
}



#SyncLogins "xxuatsql3,3655" "YYY_Musterlist"

Set-Location 'C:\Users\jorgebe\Documents\powershell' 

$z = Get_Webpage 'https://support.microsoft.com/en-us/lifecycle/search/1044'
$z



#$z = ReadActions 'D:\Users\jorgebe\Documents\powershell\ACTIONS.DAT' 'RESTORE SYSTEST'
#$z = ReadActions 'ACTIONS.DAT' 'RESTORE SYSTEST'
#$z

<#
$LogDir = ".\User-Accounts.csv"
$users = GetAllActiveDirectoryUsers
$users | Export-CSV -NoType $LogDir
exit
#>

#function ReadExcelSheet($xls, $sheetname)
#{
#	#One thing that seems to be a problem though is that even though you quit Excel, 
#	#the Excel process doesn't really terminate so you may also need
##	$ErrorActionPreference = "silentlycontinue"
#	if (ps excel) { kill -name excel} 
#	$xl=New-Object -com "Excel.Application"
#	$xl.displayalerts=$False
#	$wb=$xl.workbooks.open($xls)
#	$ws = $xl.WorkSheets.item($sheetname)
##	$wb.SaveAs($csv,$xlCSV)  
#	return $ws
##	$xl.quit()
#
#}
#$ws2 = ReadExcelSheet ('D:\Users\jorgebe\Documents\powershell\c1c2_Corporate_Port_Development.xlsx', 'Custom1')

#===================================
#$ServerInstance = "ccltstecosqldb1\tstecosql1"
#$Query = "select top  10 * from master.dbo.sysdatabases"
#
#$z = Invoke-Sqlcmd3 $ServerInstance $Query
#foreach ($x in $z)
#{
#	Write-Host $x.Name
#}

<#
name      : ASPState
dbid      : 10
sid       : {1, 5, 0, 0...}
mode      : 0
status    : 4194328
status2   : 1090519040
crdate    : 6/30/2009 10:34:09 AM
reserved  : 1/1/1900 12:00:00 AM
category  : 0
cmptlevel : 100
filename  : G:\SQLDATA\TSTECOSQL1\ASPState.mdf
version   : 661

#>

#DeleteOlderFiles($url, $ext, $days, $dbname)
#$url = 'd:\temp'
#$ext = '.sql'
#$days = 3
#$dbname = ''
#DeleteOlderFiles $url, $ext, $days, $dbname
#   

#convert system.data.row to string
#$formatOut = $formatOut + ($output[$i].ItemArray -join ",")