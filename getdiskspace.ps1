#getdiskspace_WIP.ps1
#version in C:\Users\Documents\powershell\DISKSPACE
#last modified:
#10/2/2018 added dead servers message
#10/1/2018: fixed issues, installed in production ccldevsql1


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
$global:WORKFOLDER 	=	'C:\Users\Documents\powershell\DISKSPACE'
$WEBFOLDER 			= 	'\\webserver\c$\Inetpub\wwwroot\sqldba'
$SERVERLIST     	= $global:WORKFOLDER + '\servers_list3.dat'
#$EMAILTOLIST 		= 'myemail@company.com'
$EMAILTOLIST 		= 'DL-SQLDBAS@company.com'
$FROM           	= "DiskSpaceCheck@noreply.com"
$SUBJECT        	= "Test Version - Servers Report"
$LOGMESSAGE     	= ""
$LOGFILE 	    	= $WEBFOLDER + '\check_space_new.htm'
$LOWSPACEFILE   	= $global:WORKFOLDER + '\lowspace_report.txt'
$STORAGE_DATABASE	= 'PerformanceStore_Reports'
$STORAGE_SERVER		= 'STORAGESERVER'


function ListDrives($Servername)
{
    ForEach-Object `
    {
        get-wmiobject -computername $Servername win32_logicaldisk `
        | select-object systemname, deviceID, Size, Freespace, DriveType `
    }
    
    #$r = $m.GetEnumerator() | sort -Property Machine
}


function ProcessServers($Serverlist)
{
<#
	Returns 5 lists (every list item ends in a newline)
	$Prc['message']         -> list of items with lowspace
    $Prc['fullreport']      -> all items
    $Prc['links']           -> list of links of items with lowspace
    $Prc['disksreport']   -> list of disk drives lost or gained
    $Prc['deadservers']   -> dead servers today
#>
	$Prc = @{}
    $outmessage = ""
    $fullreport = ""
    $deadservers = ""
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
            Write-Host "processing " $z
            if ($z.Contains("DEAD TODAY"))
            {
                $deadservers = $deadservers + $z + [char]10
            }
            
            
            
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
                        Write-Host 'lowspace ' $j
                        $outmessage = $outmessage + $j + [char]10
                        $p = $k.deviceid -replace(":", "$")
                        $links = $links + '\\' + $z + '\' + $p + [char]10
                    }
                    #Section for whole report-------------------------------
                    $fullreport = $fullreport + $j + [char]10
                    #Section for missing drives report----------------------------------------
                    $disksreport = $disksreport + $k.systemname + '|' + $k.deviceid + [char]10
#                    $disksreport.Add($k.systemname + '|' + $k.deviceid)
                }
            }     
        }
    }
     
    $Prc['message']         = $outmessage
    $Prc['fullreport']      = $fullreport
    $Prc['links']           = $links
    $Prc['disksreport']     = $disksreport
    $Prc['deadservers']     = $deadservers
    
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
	Set-Content ($global:WORKFOLDER + '\' + 'drives_issue_' + $dt) $record

}



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

function UpdateServerList($slist)
{
	Set-Content $slist $Null

#	$r = Invoke-Sqlcmd3 'ccluatsql1\uatsql3' 'select Machine from Master_Application_List.dbo.VW_SERVERS'
    $s = "select Machine from Master_Application_List.dbo.SERVERS_LIVE_TODAY order by Machine"

	$m = Invoke-Sqlcmd3 'ccluatsql1\uatsql3' $s
    $r = $m.GetEnumerator() | sort -Property Machine
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


#-----------Program Starts Here------------------------------

Set-Location $global:WORKFOLDER

#Deleting older file reports
$m = DeleteOlderFiles $global:WORKFOLDER '20??????.dat' $RETENTION

#updating server list file from Master_Application_List.dbo.SERVERS_LIVE_TODAY
UpdateServerList $SERVERLIST






#$r is a dictionary
#$r['message']          = $outmessage
#$r['fullreport']       = $fullreport
#$r['links']            = $links
#$r['disksreport']      = $disksreport
#$r['deadservers']      = $deadservers
#first item is message about missing drives
#the second item is the full list of drives
#the third item is the list of links for lowspace drives
#fourth is list of missing or added drives
#fifth is list of dead servers today

$r = ProcessServers $SERVERLIST

#Save to temp file values just read for disksreport
#    Set-Content ($global:WORKFOLDER + '\' + 'tmp_full_report.dat') $disksreport | sort
Set-Content ($global:WORKFOLDER + '\' + 'tmp_full_report.dat') $r['disksreport'] | sort
$disksreport = $null
    
    
#We read the previous disks report run from file
$yesterdaydata = Get-Content ($global:WORKFOLDER + '\' + 'today_full_report.dat')
$todaydata = Get-Content ($global:WORKFOLDER + '\' + 'tmp_full_report.dat')

#Now we compare with current run     
$cmp = Compare-Object -ReferenceObject $todaydata -DifferenceObject $yesterdaydata

$drivesmessage = ''
if ($cmp)
{
    $drivesmessage = $drivesmessage + "There are missing or added drives" + [char]10
    $drv = ''
    foreach ($x in $cmp)
    {
        $drv = $drv + $x + [char]10 
    }
    $drivesmessage = $drivesmessage + $drv
    SaveDay $drivesmessage

}

   
#Update disks report with current run
Set-Content ($global:WORKFOLDER + '\' + 'today_full_report.dat') $todaydata | sort
    

#==========================================================

$LOGMESSAGE0 = 'Process started' + [char]10 + (get-date) + [char]10
if ($drivesmessage -gt '')
{
    $LOGMESSAGE0 = $LOGMESSAGE0 + $drivesmessage + [char]10
}

$LOGMESSAGE1 = '---Drives with lowspace - Start ---' + [char]10 + [char]10
#if ($r['message'].Trim() -gt '')
#{  
    $array = $r['message'].Split([char]10)
    foreach ($x in $array)
    {	
    	$line = $x.Split('|')
    	if ($line.Length -gt 1)
    	{
    		$LOGMESSAGE1 = $LOGMESSAGE1 + $line[0] + ' ' + $line[1] + ' free percent: ' + $line[4] + [char]10
    	}
    }    
#}
$LOGMESSAGE1 = $LOGMESSAGE1 + [char]10 + '---Drives with lowspace - End   ---' + [char]10 + [char]10

$deadservers = $r['deadservers']
if ($deadservers -gt '')
{
     $LOGMESSAGE1 = $LOGMESSAGE1 + [char]10 + 'There are dead servers today' + [char]10 + $deadservers + [char]10

}

$LOGMESSAGE2 = 'Full Report' + [char]10
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
if ($drivesmessage -gt '')
{
    $msg = $msg + $drivesmessage + [char]10
}
if ($deadservers -gt '')
{
    $msg = $msg + $deadservers + [char]10
}



$msg = $msg + [char]10 + "Link to full report today" + [char]10 + 'http://ccldevsql1/sqldba/check_space_new.htm' + [char]10

$msg > $LOWSPACEFILE
SendMail $msg  $EMAILTOLIST $LOGFILE $FROM $SUBJECT

