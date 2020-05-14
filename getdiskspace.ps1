#getdiskspace.ps1
#version in \\CCLDEVSHRDDB1\e$\POWERSHELL (from getdiskpace_WIP.ps1)
#last modified:
#9/9/2019: removed fake workflow, did fix in PERCENTFREE, PERCENTEFREE_CD
#9/5/2019: commented all references to deadservers, tested workflow fake
#7/23/2019: changed webserver to \\ccldevshrddb1\c$\Inetpub\wwwroot\sqldba
#7/1/2019: fixed duplicate lines for CORPUATSQL1 
#6/26/2019: fixed query in updateserverlist, changed serverlist
#4/2/2019: installed it here \\CCLDEVSHRDDB1\e$\POWERSHELL, ccldevsql1 missing drives
#10/2/2018: added dead servers message
#10/1/2018: fixed issues, installed in production ccldevsql1
#9/27/2018: added detection of missing drives compared with previous run
#6/21/2018: added description to report server|drive|disksize|diskfree|freepercent
#1/29/2018: added join to SERVERS_LIVE_TODAY new table with servers responding to ping
#7/25/2017: added message notification of server with connection issues (look for $CONNECTERROR)NOT READY YET
#3/17/2017: added insert to storage table
#3/14/2017: added email of full diskspace page
#6/8/2016:  changed to use server list from Master Application List view VW_SERVERS
#9/25/2015: changed disk sizes to GB
#7/27/2015: changed display of lowreport lines like "CCLTSTECOSQL1 C: free percent: 0"
#5/26/2015: tested creation of history pages
#5/22/2015: started to work on changes requested 
#5/19/2015: had to change function GetPreviousFileName
#5/18/2015: installed in ccldevsql1, added deletion of older reports
#5/15/2015: added comparison with previous runs

#README 
#sends email with servers and drives with lowspace
#also creates webpage with all servers and drive spaces
#edit PERCENTFREE and PERCENTFREE_CD as needed
#PERCENTFREE_CD is to have a different value for the C and D drives 
#Server list comes from view VW_SERVERS from Master_Application_List
#Generates  file servers_list3.dat with processed servers


#workflow Run-Workflow 
#{
#InlineScript 
#{
        

$PERCENTFREE    = 10
$PERCENTFREE_CD = 5
$RETENTION = 15
$global:WORKFOLDER 	=	'e:\POWERSHELL'
$WEBFOLDER 			= 	'\\ccldevshrddb1\c$\Inetpub\wwwroot\sqldba'
$WEBPAGE			= 'http://ccldevshrddb1/sqldba/check_space_new.htm'
$SERVERLIST     	= $global:WORKFOLDER + '\servers_list3.dat'
#$EMAILTOLIST 		= 'jbesada@carnival.com'
$EMAILTOLIST 		= 'DL-SQLDBAS@carnival.com'
$FROM           	= "DiskSpaceCheck@noreply.com"
$SUBJECT        	= "DiskSpace - Servers Report"
$LOGMESSAGE     	= ""
$LOGFILE 	    	= $WEBFOLDER + '\check_space_new.htm'
$LOWSPACEFILE   	= $global:WORKFOLDER + '\lowspace_report.txt'
$STORAGE_DATABASE	= 'PerformanceStore_Reports'
$STORAGE_SERVER		= 'CCLDEVSHRDDB1\DEVSQL2'


function ListDrives($Servername)
{
    ForEach-Object `
    {
        get-wmiobject -computername $Servername win32_logicaldisk `
        | select-object systemname, deviceID, Size, Freespace, DriveType `
    }
}
#CCLDCESHRDSQL1
#ListDrives("CCLDCESHRDSQL1")

function ProcessServers($Serverlist)
{
<#
	Returns 4 lists (every list item ends in a newline)
	$Prc['message']         -> list of items with lowspace
    $Prc['fullreport']      -> all items
    $Prc['links']           -> list of links of items with lowspace
    $Prc['disksreport']   -> list of disk drives lost or gained
#>
	$Prc = @{}
    $outmessage = ""
    $fullreport = ""
    $disksreport = ""
    $links      = ""
    $drivesmessage = ""
    $yesterdaydata = ""
    $todaydata = ""
    $Computers = (Get-Content -Path $Serverlist) | sort
    foreach ($z in $Computers) 
    {
        if ($z -gt "" -and $z[0] -ne "#")
        {         
            $fullreport = $fullreport + "Server : " + $z + [char]10
			$erroractionpreference = "SilentlyContinue"
            $q = ListDrives($z)
            $a = $q.GetEnumerator() | sort -Property deviceID
            foreach ($k in $a)
            {
                if ($k.DriveType -eq 3 -and $k.size -ne $null)
                {
                    #Section for the lowspace report ---------------------
                    $percent = (([long] $k.freespace) / ([long] $k.size)) * 100
                    $percent = [math]::round($percent, 0)
					$ksize = [math]::round($k.size/1000000000) 
					$kfreespace = [math]::round($k.freespace/1000000000)
					$j = $k.systemname + "|" + $k.deviceid + "|" + $ksize + "|" + $kfreespace + "|" + $percent
#------------------------------------------------------------------------------
					$insline = $j.Replace('|', "','")
					$sqlinsert = "INSERT INTO " + $STORAGE_DATABASE + ".[dbo].[DISKSPACE_HISTORY]([COMPUTER],[DRIVE],[DISKSIZE],[DISKFREE],[FREEPERCENT]) "
					$sqlinsert = $sqlinsert + "VALUES('" + $insline + "')"
					$w = Invoke-Sqlcmd3 $STORAGE_SERVER $sqlinsert
#------------------------------------------------------------------------------					
					
#					if ($k.deviceid -eq 'C:' -or $k.deviceid -eq 'D:')
#					{ $PERCENTFREE = $PERCENTFREE_CD }					
                    if ($percent -lt $PERCENTFREE)
                    {   
                        $outmessage = $outmessage + $j + [char]10
                        $p = $k.deviceid -replace(":", "$")
                        $links = $links + '\\' + $z + '\' + $p + [char]10
                    }
                    #Section for whole report-------------------------------
                    $fullreport = $fullreport + $j + [char]10
                    #Section for missing drives report----------------------------------------
                    $disksreport = $disksreport + $k.systemname + '|' + $k.deviceid + [char]10       
                }
            }     
        }
    }
     
    $Prc['message']         = $outmessage
    $Prc['fullreport']      = $fullreport
    $Prc['links']           = $links
    $Prc['disksreport']     = $disksreport  
    return $Prc 
}

#Usage: SendMail message 
#       emailist (as array)
#       c:\attach1.txt;c:\attach2.txt 
#       SFASupport@noreply.com 
#       "This is the subject"
function SendMail ($report,$emailarray,$attacharray,$from,$subject)
{
    $smtpServer = "smtphost.carnival.com"
    $msg = new-object Net.Mail.MailMessage
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg.From = $from      
    foreach ($c in $emailarray)
    { 
        $msg.To.Add($c)
    }  	
	if ($attacharray -gt '')
	{
    	$attlist = $attacharray.Split(";")	
			foreach ($c in $attlist)
	    { 
	        $att = new-object Net.Mail.Attachment($c)
	        $msg.Attachments.Add($att)
	    }
	}
	
    $msg.Subject = $subject
    $msg.Body = $report
    $smtp.Send($msg)
}

function MakeHTML($message, $header="")
{
	$header = "<H1>" + $header + "</H1>"
    $OUTARRAY = "",""
	$OUTARRAY + $header + [char]10
    $OUTARRAY + "<html><body>" + [char]10 
    $LST = $message.Split([char]10)
    foreach ($x in $LST)
    {
       $OUTARRAY + $x + "<br>" + [char]10 
    }
    $OUTARRAY + "</body></html>" + [char]10 
    return $OUTARRAY
}

#function SaveDay($record)
#{
#
#	$dt = (get-date -format yyyyMMdd) + '.dat'
#	Set-Content ($global:WORKFOLDER + '\' + 'drives_issue_' + $dt) $record
#}



#Fixed: the previous version commented above failed in CCLDEVSQL1
#Purpose: get latest .dat file with this form YYYYMMDD.dat in the workfolder
#this one works
#function GetPreviousFileName($fldr, $ext='.dat')
#{
#	$list = @()
#	$z = dir $fldr -Filter 20*$ext
#	foreach ($x in $z)
#	{
#		$list += $fldr + '\' + $x.Name
#	}	
#	return $list[0]
#}


#function DeleteOlderFiles($url, $ext, $days)
#{
#	$d = Get-Date
#	$a = @{}
#	$files = Get-ChildItem -Filter $ext $url
#	if ($files.Count -gt 0)
#	{
#      foreach ($f in $files)
#      {
#		if (($d - $f.LastWriteTime).Days -gt $days)
#		{
#	 		Remove-Item  $url\$f -Force
#		}
#		else
#		{
#			$a[$f.Name] = $f.LastWriteTime			
#		}
#    }	
#  }
#  $b = $a.GetEnumerator() | Sort-Object 'Value' -Descending
#  return $b
#}

#$global:WORKFOLDER = 	'c:\Users\jorgebe\Documents\powershell'
#$m = DeleteOlderFiles $global:WORKFOLDER '2015????.dat' 3
#$m

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

#fixed query adding is null
function UpdateServerList($slist)
{
	Set-Content $slist $Null
    $s = "select Machine from Master_Application_List.dbo.SERVERS_LIVE_TODAY "
	$s = $s + " where status is null order by Machine"
	$m = Invoke-Sqlcmd3 $STORAGE_SERVER $s
    $r = $m.GetEnumerator() | sort -Property Machine
	if ($r.Count -gt 0)
	{
		foreach ($x in $r)
		{ Add-Content $slist $x.Machine}
	}
}


#-----------Program Starts Here------------------------------

Set-Location $global:WORKFOLDER

#updating server list file from Master_Application_List.dbo.SERVERS_LIVE_TODAY
UpdateServerList $SERVERLIST






#$r is a dictionary
#$r['message']          = $outmessage
#$r['fullreport']       = $fullreport
#$r['links']            = $links
#$r['disksreport']      = $disksreport
#first item is message about missing drives
#the second item is the full list of drives
#the third item is the list of links for lowspace drives
#fourth is list of missing or added drives


$r = ProcessServers $SERVERLIST
$disksreport = ''        
$drivesmessage = ''
#==========================================================

$LOGMESSAGE0 = 'Process started' + [char]10 + (get-date) + [char]10
$LOGMESSAGE1 = '---Drives with lowspace - Start ---' + [char]10 + [char]10
if ($r['message'].Trim() -gt '')
{  
    $array = $r['message'].Split([char]10)
    foreach ($x in $array)
    {	
    	$line = $x.Split('|')
    	if ($line.Length -gt 1)
    	{
    		$LOGMESSAGE1 = $LOGMESSAGE1 + $line[0] + ' ' + $line[1] + ' free percent: ' + $line[4] + [char]10
    	}
    }    
}
$LOGMESSAGE1 = $LOGMESSAGE1 + [char]10 + '---Drives with lowspace - End   ---' + [char]10 + [char]10
$LOGMESSAGE2 = 'Full Report' + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + 'Drive|Total|Free|Free%' + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + $r['fullreport'] + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + 'Process completed ' + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + (get-date) + [char]10




#Send email
$hd = "Disk Space Report - server|drive|disksize|diskfree|freepercent " + (Get-Date).ToString()
$g = MakeHTML ($LOGMESSAGE0 + $LOGMESSAGE1 + $LOGMESSAGE2) $hd
$g > $LOGFILE




if ($r['message'].length -gt 0)
{
    $msg = "There is lowspace (server|drive|disksize|diskfree|freepercent)" + [char]10 + [char]10 + $LOGMESSAGE1 + [char]10	
    $msg = $msg + 'Links to lowspace drives:' + [char]10 + $r['links'] + [char]10
}
else
{
    $msg = "No lowspace today" + [char]10
}
#if ($drivesmessage -gt '')
#{
#    $msg = $msg + $drivesmessage + [char]10
#}
#if ($deadservers -gt '')
#{
#    $msg = $msg + $deadservers + [char]10
#}



#$msg = $msg + [char]10 + "Link to full report today" + [char]10 + 'http://ccldevsql1/sqldba/check_space_new.htm' + [char]10
$msg = $msg + [char]10 + "Link to full report today" + [char]10 + $WEBPAGE + [char]10


$msg > $LOWSPACEFILE
SendMail $msg  $EMAILTOLIST $LOGFILE $FROM $SUBJECT

        
#} #endregion of inlinescript
#} #endregion of workflow
#
#Run-Workflow