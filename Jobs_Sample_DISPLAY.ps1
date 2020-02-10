# Jobs_Sample.ps1 uses Job_CodeBlocks.ps1
Set-Location C:\CODECAMP
. C:\CODECAMP\Jobs_CodeBlocks.ps1 # magic here, we know this works

$listofservers = Get-Content -Path 'DBLIST_ACTIONS.TXT'
$CONCURRENCY = 10

"Killing existing jobs . . ." # Good practice
Get-Job | Remove-Job -Force
"Done."
" "

foreach ($k in $listofservers)
{
    $a = $k.Split('|') #assign to variables for clarity
    $SOURCESERVER = $a[0];$BACKUPFILE = $a[1];$SOURCEDB = $a[2];$DESTSERVER = $a[3]
    $DATAFOLDER = $a[4];$LOGFOLDER = $a[5];$DESTDB = $a[6];$ACTIONS = $a[7];$ENABLED = $a[8]

    $restore_options = @{}		
    $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
    if ($running.Count -le $CONCURRENCY -and $ENABLED -eq 'Y') 
    {	
      if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_RECOVERY')
      {		
        $restore_options['restore_type'] = 'DATABASE'
        $restore_options['recovery'] = 'RECOVERY'
        $restore_options['replace'] = $True	
        Start-Job -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER ,$BACKUPFILE, 'etc' )				
      }
			# more action cases here like RESTORE_DATABASE_FULL_WITH_NORECOVERY, omitted here
    }
    else
    { 
      $running | Wait-Job
    }		 
}
Get-Job | Receive-Job

