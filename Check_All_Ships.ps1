#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   3/11/2019 10:57 AM
# Created by:   jorgebe
#Last updated: 8/30/2019
# PROD version in \\ccldevshrddb1\e$\POWERSHELL
# Organization: 
# Filename: Check_All_Ships.ps1    
#========================================================================

#===============GLOBALS=======================================
$WORKFOLDER = 'e:\POWERSHELL'
$SERVERLIST = $WORKFOLDER + '\SHIPSLIST.TXT'
$CONCURRENT = 20
$LOGFILE 	= $WORKFOLDER + '\ping_status_all.html'
$WEBPAGE = 'C:\INETPUB\WWWROOT\SQLDBA\ping_status_all.html'
$global:S = ''
#=============================================================


#===============SCRIPT BLOCKS=================================
$CheckPing = 
{
  #param ($server, $outfile, $global:S)
  param ($server)
  $v = (ping $server -n 1)
  #	Start-Sleep 5
  foreach ($k in $v)
  {
    if ($k.StartsWith("Reply"))
    { break }
    else
    { if ($k.StartsWith("Request timed out")) { return ""  }	}
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
      #$s = $server , $p2
      $s = $server + '|' + $p2.ToString()
      #		$s = $server + [char]9 + $p2.ToString()
    }
    else
    {
      #$s = $server, 0
      $s = $server + '|0'
      #		$s = $server + [char]9  + '0'
    }
    #Add-Content -Path $outfile $s
    #$global:S = $global:S + $s + [char]13	
    return $s	
}


function MakeHTML($message, $header="")
{
  $header = "<H1>" + $header + "</H1>"
    $OUTARRAY = "",""
  $OUTARRAY + $header + [char]10
    $OUTARRAY + "<html><body>" + [char]10 
    foreach ($x in $message)
    {
       $OUTARRAY + $x.Server + [char]9 + $x.Ping + "<br>" + [char]10 
    }
    $OUTARRAY + "</body></html>" + [char]10 
    return $OUTARRAY
}
#$g = MakeHTML ($LOGMESSAGE0 + $LOGMESSAGE1 + $LOGMESSAGE2) $hd
#$g > $LOGFILE


#============================================================
 
Set-Location -Path $WORKFOLDER
#====================PROGRAM STARTS HERE=====================
cls
"Process started " 
$d1 = Get-Date
$d1
" "
$outfile = $WORKFOLDER + '\CheckPing.out'
#Set-Content -Path $outfile $False


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
    #      $msg
      $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
    if ($running.Count -le $CONCURRENT) 
    {
      $null = (Start-Job -Name 'CheckPing' -ScriptBlock $CheckPing -ArgumentList ($x))		
    }
    else
    { 
      $running | Wait-Job
    }
  }
}
Start-Sleep 60 #IMPORTANT MAGIC HERE: needed to get the last items of the list
$global:S = (Get-Job -Name 'CheckPing'  | Receive-Job )



Add-Content -Path $outfile $global:S
$date = (Get-Date).ToString()
$csv = Import-Csv -Header "Server", "Ping"  -delimiter '|' $outfile
$csv | % { $_.Ping = [int]$_.Ping }
$r = ($csv | Sort-Object Ping)


$header = 'Ping of all ships XXSQL3 to XXSQL6 - ' + $date + ' - 0 means no response'
$webpage1 = MakeHTML $r $header

Set-Content $WEBPAGE $webpage1
#-----------


$d2 = Get-Date
$diff = $d2 - $d1
"Process ended: "
$diff

Set-Content -Path $outfile ''


