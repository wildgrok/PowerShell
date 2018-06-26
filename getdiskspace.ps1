#getdiskspace.ps1
#version in \\ccldevsql1\k$\POWERSHELL\DISKSPACE
#last modified: 
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


$PERCENTFREE    = 10
$PERCENTFREE_CD = 5
$RETENTION = 15
$global:WORKFOLDER 	=	'k:\POWERSHELL\DISKSPACE'
$WEBFOLDER 			= 	'c:\Inetpub\wwwroot\sqldba'
$SERVERLIST     	= $global:WORKFOLDER + '\servers_list3.dat'
#$EMAILTOLIST 		= 'jbesada@carnival.com'
$EMAILTOLIST 		= 'DL-SQLDBAS@carnival.com'
$FROM           	= "DiskSpaceCheck@noreply.com"
$SUBJECT        	= "Servers Lowspace Report"
$LOGMESSAGE     	= ""
$LOGFILE 	    	= $WEBFOLDER + '\check_space.htm'
$LOWSPACEFILE   	= $global:WORKFOLDER + '\lowspace_report.txt'
$WEBPAGE_DAY		= 'http://ccldevsql1/sqldba/check_space.htm'
$WEBPAGE_HISTORY	= 'http://ccldevsql1/sqldba/check_space_history.htm'
$STORAGE_DATABASE	= 'PerformanceStore_Reports'
$STORAGE_SERVER		= 'CCLDEVSHRDDB1\DEVSQL2'
# New 7/25/2017
$CONNECTERROR 		= ""

function ListDrives($Servername)
{
    ForEach-Object `
    {
        get-wmiobject -computername $Servername win32_logicaldisk `
        | select-object systemname, deviceID, Size, Freespace, DriveType `
    }
}
# $a = ListDrives 'ZZSQL4N1.shipdev.carnival.com'

function ProcessServers($Serverlist)
{
<#
	Returns 3 lists (every list item ends in a newline)
	
	first list: 	list of items with lowspace
	second list: 	all items
	third list: 	list of links of items with lowspace
	
	Also creates dated file with lowspace entries
	Sample file:
	20150513.dat
#>
	
    $outmessage = ""
    $fullreport = ""
    $links      = ""
    $Computers = Get-Content -Path $Serverlist;
	#$r = Invoke-Sqlcmd3 'ccluatsql1\uatsql3' 'select Machine from Master_Application_List.dbo.VW_SERVERS'
	#$Computers = $r.Machine
    foreach ($z in $Computers) 
    {
        if ($z -gt "" -and $z[0] -ne "#")
        {
            $fullreport = $fullreport + "Server : " + $z + [char]10
#			$erroractionpreference = "SilentlyContinue"
            $a = ListDrives($z)
#			Write-Host "$a.Count = " $a.Count
#			if ($a.Count -lt 3)
#			{
#				$CONNECTERROR = [char]10 + $z + $CONNECTERROR
#			}
            foreach ($k in $a)
            {
                if ($k.DriveType -eq 3 -and $k.size -ne $null)
                {
                    #Section for the lowspace report ---------------------
                    $percent = (([long] $k.freespace) / ([long] $k.size)) * 100
                    $percent = [math]::round($percent, 0)
					$ksize = [math]::round($k.size/1000000000) 
					$kfreespace = [math]::round($k.freespace/1000000000)
					
#                    $j = $k.systemname + "|" + $k.deviceid + "|" + ($k.size/1000000000) + "|" + ($k.freespace/1000000000) + "|" + $percent
					$j = $k.systemname + "|" + $k.deviceid + "|" + $ksize + "|" + $kfreespace + "|" + $percent
#------------------------------------------------------------------------------
					$insline = $j.Replace('|', "','")
					$sqlinsert = "INSERT INTO " + $STORAGE_DATABASE + ".[dbo].[DISKSPACE_HISTORY]([COMPUTER],[DRIVE],[DISKSIZE],[DISKFREE],[FREEPERCENT]) "
					$sqlinsert = $sqlinsert + "VALUES('" + $insline + "')"
#					write-host $sqlinsert
					$w = Invoke-Sqlcmd3 $STORAGE_SERVER $sqlinsert
#------------------------------------------------------------------------------					
					
					if ($k.deviceid -eq 'C:' -or $k.deviceid -eq 'D:')
					{
						$PERCENTFREE = $PERCENTFREE_CD
					}
					
                    if ($percent -lt $PERCENTFREE)
                    {   
                        $outmessage = $outmessage + $j + [char]10
                        $p = $k.deviceid -replace(":", "$")
                        $links = $links + '\\' + $z + '\' + $p + [char]10
                    }
                    #Section for whole report-------------------------------
                    $fullreport = $fullreport + $j + [char]10
                }
            }     
        }
    }
	SaveDay $outmessage
    return $outmessage, $fullreport, $links
    
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
        #write-host($c) 
        $msg.To.Add($c)
    }  
	
	if ($attacharray -gt '')
	{
    	$attlist = $attacharray.Split(";")
	
	
			foreach ($c in $attlist)
	    { 
	        #write-host($c) 
	        $att = new-object Net.Mail.Attachment($c)
	        $msg.Attachments.Add($att)
	    }
	}
	
    $msg.Subject = $subject
    $msg.Body = $report
    $smtp.Send($msg)
}

#function AddToLog($line)
#{
#    #add-content -Path $LOGFILE -Value ($line)
#    out-file -filepath $LOGFILE -inputobject $line -append -force
#}

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




#Fixed: the previous version commented above failed in CCLDEVSQL1
#Purpose: get latest .dat file with this form YYYYMMDD.dat in the workfolder
#this one works
function GetPreviousFileName($fldr, $ext='.dat')
{
	$list = @()
	$z = dir $fldr -Filter 20*$ext
	foreach ($x in $z)
	{
		$list += $fldr + '\' + $x.Name
	}	
	return $list[0]
}


<#
Checking file  20150512.dat dated  5/14/2015 10:39:53 AM
Keeping file  20150512.dat dated  5/14/2015 10:39:53 AM
Checking file  20150513.dat dated  5/13/2015 2:39:27 PM
Keeping file  20150513.dat dated  5/13/2015 2:39:27 PM
Checking file  20150515.dat dated  5/15/2015 5:21:32 PM
Keeping file  20150515.dat dated  5/15/2015 5:21:32 PM
Checking file  20150518.dat dated  5/18/2015 10:43:51 AM
Keeping file  20150518.dat dated  5/18/2015 10:43:51 AM

Name                           Value                                                                                         
----                           -----                                                                                         
20150518.dat                   5/18/2015 10:43:51 AM                                                                         
20150515.dat                   5/15/2015 5:21:32 PM                                                                          
20150512.dat                   5/14/2015 10:39:53 AM                                                                         
20150513.dat                   5/13/2015 2:39:27 PM                                                                          


#>

function DeleteOlderFiles($url, $ext, $days)
{
	$d = Get-Date
	$a = @{}
	$files = Get-ChildItem -Filter $ext $url
	if ($files.Count -gt 0)
	{
      foreach ($f in $files)
      {
		write-host  'Checking file ' $f.Name 'dated '  $f.LastWriteTime 
		if (($d - $f.LastWriteTime).Days -gt $days)
		{
			write-host  'Deleting file ' $f.Name 'dated '  $f.LastWriteTime
	 		Remove-Item  $url\$f -Force
		}
		else
		{
			write-host  'Keeping file ' $f.Name 'dated '  $f.LastWriteTime
			$a[$f.Name] = $f.LastWriteTime			
		}
    }	
  }
  $b = $a.GetEnumerator() | Sort-Object 'Value' -Descending
  return $b
}

#$global:WORKFOLDER = 	'D:\Users\jorgebe\Documents\powershell'
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
#Updated 1/29/2018
function UpdateServerList($slist)
{
	Set-Content $slist $Null

#	$r = Invoke-Sqlcmd3 'ccluatsql1\uatsql3' 'select Machine from Master_Application_List.dbo.VW_SERVERS'
	$r = Invoke-Sqlcmd3 'ccluatsql1\uatsql3' 'select Machine from Master_Application_List.dbo.SERVERS_LIVE_TODAY'
	write-host "r."
	write-host $r.Machine
	if ($r.Count -gt 0)
	{
		write-host "count:"
		write-host $r.Count		
		foreach ($x in $r)
		{ Add-Content $slist $x.Machine}
	}
	else{ write-host "No records" }
}
#UpdateServerList '\\ccldevsql1\k$\POWERSHELL\DISKSPACE\servers_list3.dat'


#-----------Program Starts Here------------------------------

#Set-Location $global:WORKFOLDER

$LOGMESSAGE0 = $LOGMESSAGE0 + 'Process started' + [char]10
$LOGMESSAGE0 = $LOGMESSAGE0 + (get-date) + [char]10

#Deleting older file reports
$m = DeleteOlderFiles $global:WORKFOLDER '20??????.dat' $RETENTION
$m

#NEW: updating server list file from Master_Application_List database view VW_SERVERS
UpdateServerList $SERVERLIST
get-content $SERVERLIST



#$r is an array
#first item the list of drives with reported lowspace
#the second item is the full list of drives
#the third item is the list of links

$r = ProcessServers $SERVERLIST

$LOGMESSAGE1 = $LOGMESSAGE1 + '---Drives with lowspace - Start ---' + [char]10 + [char]10

# original, put back 
#$LOGMESSAGE1 = $LOGMESSAGE1 + $r[0] + [char]10
# Modified 7/27/2015
$array = $r[0].Split([char]10)
foreach ($x in $array)
{
	
	$line = $x.Split('|')
	if ($line[0] -gt '')
	{
		$LOGMESSAGE1 = $LOGMESSAGE1 + $line[0] + ' ' + $line[1] + ' free percent: ' + $line[4] + [char]10
	}

}

$LOGMESSAGE1 = $LOGMESSAGE1 + [char]10 + '---Drives with lowspace - End   ---' + [char]10 + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + 'Full Report' + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + $r[1] + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + 'Process completed ' + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + (get-date) + [char]10


#Send email
$hd = "Disk Space Report - server|drive|disksize|diskfree|freepercent " + (Get-Date).ToString()
$g = MakeHTML ($LOGMESSAGE0 + $LOGMESSAGE1 + $LOGMESSAGE2) $hd
$g > $LOGFILE




if ($r[0].length -gt 0)
{
#    $msg = "There is lowspace (server|drive|disksize|diskfree|freepercent)" + [char]10 + [char]10 + $r[0] + [char]10
    $msg = "There is lowspace (server|drive|disksize|diskfree|freepercent)" + [char]10 + [char]10 + $LOGMESSAGE1 + [char]10	
    $msg = $msg + 'Links to lowspace drives:' + [char]10 + $r[2]
}
else
{
    $msg = "No lowspace today" + [char]10
}

#if ($CONNECTERROR -ne "")
#{
#	$msg = $msg + [char]10 + "Servers with connection issues:" + [char]10 + $CONNECTERROR + [char]10	
#}


#$msg = $msg + [char]10 + "Link to full report today" + [char]10 + 'http://ccldevsql1/sqldba/check_space.htm' + [char]10
$msg = $msg + [char]10 + "Link to full report today" + [char]10 + $WEBPAGE_DAY + [char]10


#$msg = $msg + [char]10 + "Link to history pages" + [char]10 + 'http://ccldevsql1/sqldba/check_space_history.htm' + [char]10
$msg = $msg + [char]10 + "Link to history pages" + [char]10 + $WEBPAGE_HISTORY + [char]10


#Saving copy of the report in file

#$msg = $msg + [char]10 + "Comparison file: " + $previousfile + [char]10

$msg > $LOWSPACEFILE
#SendMail ($report,$emailarray,$attacharray,$from,$subject)
SendMail $msg  $EMAILTOLIST $LOGFILE $FROM $SUBJECT













