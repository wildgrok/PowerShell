#getdiskspace_production.ps1
#version in c:\temp (from getdiskpace.ps1 in ccldevshrddb1\e$\powershell, 5/11/2020)
#last modified:5/12/2020
#workflow Run-Workflow 
#{
#InlineScript 
#{
        
$PERCENTFREE    = 10
# $PERCENTFREE_CD = 5
# $RETENTION = 15
$global:WORKFOLDER 	=	'C:\TEMP'
$WEBFOLDER 			= 	'\\ccldevshrddb1\c$\Inetpub\wwwroot\sqldba'
$WEBPAGE			= 'http://ccldevshrddb1/sqldba/check_space_production_test.htm'
# $SERVERLIST     	= $global:WORKFOLDER + '\SQL_Access_Status_Saurabh_Full_Simple.csv'
$SERVERLIST     	= $global:WORKFOLDER + '\SQL_Access_Status_Saurabh_SHORTLIST.csv'
$EMAILTOLIST 		= 'jbesada@carnival.com'
#$EMAILTOLIST 		= 'DL-SQLDBAS@carnival.com'
$FROM           	= "DiskSpaceCheckProduction@noreply.com"
$SUBJECT        	= "DiskSpace Production - Servers Report"
# $LOGMESSAGE     	= ""
$LOGFILE 	    	= $WEBFOLDER + '\check_space_production_test.htm'
$LOWSPACEFILE   	= $global:WORKFOLDER + '\lowspace_production_report_test.txt'
$STORAGE_DATABASE	= 'PerformanceStore_Reports'
$STORAGE_SERVER		= 'CCLDEVSHRDDB1\DEVSQL2'
$PROCESS_STARTED = get-date


#-----------------functions-------------------------------------
function Write_to_CSV($array, $file)
{
    Set-Content -Path $file 'Server,Machine,Drive,Total,Free,Free%'
    $storage = ''
    foreach ($k in $array)
    {
        $line = $k.ToString().Replace('|',',')
        $line  
        $storage = $storage + $line + [char]10             
    }
    Add-Content -Path $file -Value $storage
}


function ExtractMachine($server)
{
    if ($server.Contains('\'))
    {
        $s1 = $server.Split('\')[0]
        return $s1
    }
    if ($server.Contains(','))
    {
        $s1 = $server.Split(',')[0]
        return $s1
    }   
}

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
    # $drivesmessage = ""
    # $yesterdaydata = ""
    # $todaydata = ""
    #$Computers = (Get-Content -Path $Serverlist) | sort
    $trc = "TRUNCATE TABLE " + $STORAGE_DATABASE + ".[dbo].[DISKSPACE_PRODUCTION]"
    $w = Invoke-Sqlcmd3 $STORAGE_SERVER $trc

    $Computers = Import-Csv -Path $Serverlist | Sort-Object ServerName
    $memory = ''
    foreach ($sv in $Computers) #--------------start big foreach----------------------------
    {
        $z = ExtractMachine($sv.ServerName)
        
        if (($z -gt "") -and ($z[0] -ne "#") -and ($z -ne $memory))
        {     
            ####CHANGED    
            #$fullreport = $fullreport + "Server : " + $z + [char]10
            $erroractionpreference = "SilentlyContinue"
            $q = ListDrives($z)
            $a = $q.GetEnumerator() | sort-object -Property deviceID
            foreach ($k in $a)
            {
                if ($k.DriveType -eq 3 -and $k.size -ne $null)
                {
                    #Section for the lowspace report ---------------------
                    $percent = (([long] $k.freespace) / ([long] $k.size)) * 100
                    $percent = [math]::round($percent, 0)
					$ksize = [math]::round($k.size/1000000000) 
                    $kfreespace = [math]::round($k.freespace/1000000000)
                    ####CHANGED
                    # $j = $k.systemname + "|" + $k.deviceid + "|" + $ksize + "|" + $kfreespace + "|" + $percent
                    $j = $z + "|" + $k.systemname + "|" + $k.deviceid + "|" + $ksize + "|" + $kfreespace + "|" + $percent
#------------------------------------------------------------------------------
                    # [SERVER] [varchar](100) NULL,
                    # [COMPUTER] [varchar](100) NULL,
                    # [DRIVE] [varchar](10) NULL,
                    # [DISKSIZE] [varchar](50) NULL,
                    # [DISKFREE] [varchar](50) NULL,
                    # [FREEPERCENT] [varchar](50) NULL,
                    # [TIMERECORDED] [datetime] NOT NULL
					$insline = $j.Replace('|', "','")
					$sqlinsert = "INSERT INTO " + $STORAGE_DATABASE + ".[dbo].[DISKSPACE_PRODUCTION]([SERVER],[COMPUTER],[DRIVE],[DISKSIZE],[DISKFREE],[FREEPERCENT]) "
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
            $memory = $m    
        }
        
    } #----------------------------------end of big foreach-------------------------
     
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
        $m = $x.Split("|")
        $b = $m[-1]
         if ($b -lt 11)
        { $OUTARRAY + '<b>' + $x + '</b>' +"<br>" + [char]10 }
         else
         { $OUTARRAY + $x + "<br>" + [char]10 }
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

#-----------------functions end-------------------------------------


#-----------Program Starts Here-------------------------------------------------------------------------------------
Set-Location $global:WORKFOLDER
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
# $r['fullreport']
# $r['fullreport']   | Select-Object * | Export-Csv -Path .\FullReport.Csv -NoTypeInformation
# Get-Content -Path .\FullReport.Csv
$file = "c:\temp\data.csv"
Write_to_CSV $r['fullreport'] $file 

# $disksreport = ''        
# $drivesmessage = ''
#==========================================================

$LOGMESSAGE0 = 'Process started' + [char]10 + $PROCESS_STARTED + [char]10
# $LOGMESSAGE1 = '---Drives with lowspace - Start ---' + [char]10 + [char]10
# if ($r['message'].Trim() -gt '')
# {  
#     $array = $r['message'].Split([char]10)   
#     foreach ($x in $array)
#     {	
#     	$line = $x.Split('|')
#     	if ($line.Length -gt 1)
#     	{
#     		$LOGMESSAGE1 = $LOGMESSAGE1 + $line[0] + ' ' + $line[1] + ' free percent: ' + $line[4] + [char]10
#         }
#     }    
# }
# $LOGMESSAGE1 = $LOGMESSAGE1 + [char]10 + '---Drives with lowspace - End   ---' + [char]10 + [char]10
$LOGMESSAGE2 = 'Full Report' + [char]10
####CHANGED
$LOGMESSAGE2 = $LOGMESSAGE2 + 'Server|Machine|Drive|Total|Free|Free%' + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + $r['fullreport'] + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + 'Process completed ' + [char]10
$LOGMESSAGE2 = $LOGMESSAGE2 + (get-date) + [char]10

#Send email
####CHANGED
$hd = "Disk Space Report - server|machine|drive|disksize|diskfree|freepercent " + (Get-Date).ToString()
# $g = MakeHTML ($LOGMESSAGE0 + $LOGMESSAGE1 + $LOGMESSAGE2) $hd
$g = MakeHTML ($LOGMESSAGE0  + $LOGMESSAGE2) $hd
$g > $LOGFILE

$msg = ''
# if ($r['message'].length -gt 0)
# {
#     $msg = "There is lowspace (server|drive|disksize|diskfree|freepercent)" + [char]10 + [char]10 + $LOGMESSAGE1 + [char]10	
#     $msg = $msg + 'Links to lowspace drives:' + [char]10 + $r['links'] + [char]10
# }
# else
# {
#     $msg = "No lowspace today" + [char]10
# }

#$msg = $msg + [char]10 + "Link to full report today" + [char]10 + 'http://ccldevsql1/sqldba/check_space_new.htm' + [char]10
$msg = $msg + [char]10 + "Link to full report today" + [char]10 + $WEBPAGE + [char]10
$msg > $LOWSPACEFILE
SendMail $msg  $EMAILTOLIST $LOGFILE $FROM $SUBJECT

        
#} #endregion of inlinescript
#} #endregion of workflow
#
#Run-Workflow