# Jobs_Sample.ps1
# Uses Job_CodeBlocks.ps1

Set-Location C:\CODECAMP
# magic here, we know this works importing all script blocks
. C:\CODECAMP\Jobs_CodeBlocks.ps1

$listofservers = Get-Content -Path 'DBLIST_ACTIONS.TXT'
$CONCURRENCY = 10


"Killing existing jobs . . ."
Get-Job | Remove-Job -Force
"Done."
" "

$cnt = 0
foreach ($k in $listofservers)
{
  if ($cnt -gt 0)
  {
    $a = $k.Split('|')
    $SOURCESERVER = $a[0]
    $BACKUPFILE = $a[1]
    $SOURCEDB = $a[2]
    $DESTSERVER = $a[3]
    $DATAFOLDER = $a[4]
    $LOGFOLDER = $a[5]
    $DESTDB = $a[6]
    $ACTIONS = $a[7]
    $ENABLED = $a[8]
				
    $restore_options = @{}		
    $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
    if ($running.Count -le $CONCURRENCY -and $ENABLED -eq 'Y') 
    {	
      if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_RECOVERY')
      {		
        $restore_options['restore_type'] = 'DATABASE'
        $restore_options['recovery'] = 'RECOVERY'
        $restore_options['replace'] = $True	
        Start-Job -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER ,$BACKUPFILE ,$SOURCEDB, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options) 	#| Out-Null				
      }
			
      if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_NORECOVERY')
      {		
        $restore_options['restore_type'] = 'DATABASE'
        $restore_options['recovery'] = 'NORECOVERY'
        $restore_options['replace'] = $True
        Start-Job -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER ,$BACKUPFILE,$SOURCEDB, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options) 			
      }
			
      if ($ACTIONS -eq 'RESTORE_LOGS_WITH_NORECOVERY')
      {		
        $restore_options['restore_type'] = 'LOG'
        $restore_options['recovery'] = 'NORECOVERY'
        $restore_options['replace'] = $True	
        Start-Job -ScriptBlock $RestoreLogs -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $restore_options) 			
      }
			
      if ($ACTIONS -eq 'RESTORE_LOGS_WITH_RECOVERY')
      {		
        $restore_options['restore_type'] = 'LOG'
        $restore_options['recovery'] = 'RECOVERY'
        $restore_options['replace'] = $True					
        Start-Job -ScriptBlock $RestoreLogs -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $restore_options) 				
      }
    }
    else
    { 
      $running | Wait-Job
    }		
  }
	$cnt++
}
Get-Job | Receive-Job

