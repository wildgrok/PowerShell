#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   3/11/2019 10:57 AM
# Created by:   jorgebe
#Last updated: 3/13/2019
# "Production" version in CCLDEVSQL1
# Organization: 
# Filename: Check_All_Ships.ps1    
#========================================================================

#===============GLOBALS=======================================
$WORKFOLDER = 'c:\Inetpub\wwwroot\sqldba'
$SERVERLIST = $WORKFOLDER + '\SHIPSLIST.TXT'
$CONCURRENT = 10
$LOGFILE 	= $WORKFOLDER + '\ping_status_all.html'
#=============================================================


#===============SCRIPT BLOCKS=================================
$CheckPing = 
{
	param ($server)
	$v = (ping $server -n 1)
#	Start-Sleep 5
	foreach ($k in $v)
	{
		if ($k.StartsWith("Reply"))
		{ break }
		else
		{ if ($k.StartsWith("Request timed out")) { return "" }	}
	}
	$l = $k.Replace('<', '=')
	$lst = $l.split('=')[2]
	if ($lst)
	{ $ping = $lst.Replace('ms TTL', '') }
	else { $ping = "" }		
    $p = $ping.Trim()
    $p2 = [int]$p
    if ($p -gt "")  
    {
		$s = $server + ',' + $p2.ToString()
    }
    else
    {
		$s = $server + ',0'
    }
	$s		
}

#============================================================
 
Set-Location -Path $WORKFOLDER
#====================PROGRAM STARTS HERE=====================
cls
"Process started " 
$d1 = Get-Date
$d1
" "
Set-Content -Path ($WORKFOLDER + '\CheckPing.out') 'server,ping'


"Killing existing jobs . . ."
Get-Job | Remove-Job -Force
"Done."
" "


$slist = Get-Content -Path $SERVERLIST
foreach ($x in $slist)
{
	if ($x.Trim() -gt '' )
	{
		$msg = "Processing " + $x
	    $msg
	    $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
		if ($running.Count -le $CONCURRENT) 
		{
			$null = (Start-Job -Name 'CheckPing' -ScriptBlock $CheckPing -ArgumentList ($x))			
		}
		else
		{ 
			$running | Wait-Job
		}
		Start-Sleep 5
		Add-Content -Path ($WORKFOLDER + '\CheckPing.out') ( Get-Job -Name 'CheckPing'  | Receive-Job )	
	}
}

#-----------
$date = (Get-Date).ToString()
$a = "<html><title>Ping of all SQL Server ships - " + $date + "</title><body>" + [char]13 + [char]10
$a = $a + "<H1>Ping of all ships XXSQL3, XXSQL4, XXSQL5 - " + $date + "</H1>" + [char]13 + [char]10
$a = $a + "<br><b>Zero means no ping response<br></b><br><br>" + [char]13 + [char]10


$r = Get-Content -Path ($WORKFOLDER + '\CheckPing.out')
foreach ($x in $r)
{
	if ($x.Trim() -gt '')
	{
		$k = $x.Split(",")
		$a = $a +  $k[0] + " ---- " + $k[1] + "<br>" + [char]13 + [char]10
	}
}
$a = $a + "</body></html>"
Set-Content $LOGFILE $a
#-----------

"Process ended in seconds:" 
$d2 = Get-Date
$diff = $d2 - $d1
$diff.Seconds



