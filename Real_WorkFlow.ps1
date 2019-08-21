#Real_WorkFlow.ps1 - uses same Jobs_CodeBlocks.ps1

workflow Run-Workflow 
{ # start of workflow
  param($listofservers)  
    InlineScript
    {
      "Parallel process to start . . ."    
    }

    foreach -parallel ($k in $listofservers)
    {
      InlineScript
      {
        . C:\Users\jorgebe\Documents\OneDrive\Briefcase_CCL\PASS2019\Jobs_CodeBlocks.ps1
          $a = ($using:k).Split('|')
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
				
          if ($ENABLED -eq 'Y') 
          {	
            if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_RECOVERY')
            {		
              $restore_options['restore_type'] = 'DATABASE'
              $restore_options['recovery'] = 'RECOVERY'
              $restore_options['replace'] = $True            
              $null = Invoke-Command -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options)				
            }
			
            if ($ACTIONS -eq 'RESTORE_DATABASE_FULL_WITH_NORECOVERY')
            {	
              $restore_options['restore_type'] = 'DATABASE'
              $restore_options['recovery'] = 'NORECOVERY'
              $restore_options['replace'] = $True
              $null = Invoke-Command -ScriptBlock $RestoreDatabase -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $LOGFOLDER, $DATAFOLDER, $restore_options)				
            }		
			
            if ($ACTIONS -eq 'RESTORE_LOGS_WITH_NORECOVERY')
            {
              $restore_options['restore_type'] = 'LOG'
              $restore_options['recovery'] = 'NORECOVERY'
              $restore_options['replace'] = $True
              $null = Invoke-Command -ScriptBlock $RestoreLogs -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $restore_options) 					
            }			
			
            if ($ACTIONS -eq 'RESTORE_LOGS_WITH_RECOVERY')
            {		
              $restore_options['restore_type'] = 'LOG'
              $restore_options['recovery'] = 'RECOVERY'
              $restore_options['replace'] = $True
              $null = Invoke-Command -ScriptBlock $RestoreLogs -ArgumentList ($DESTSERVER,$BACKUPFILE, $SOURCEDB, $DESTDB, $restore_options) 					
            }			
          }	        
      }   # end of inlinescript
    }     # end of foreach
    
    InlineScript
    {
      "Parallel process completed . . ."    
    }         
}         # end of workflow	

Set-Location C:\Users\jorgebe\Documents\OneDrive\Briefcase_CCL\PASS2019
$list = Get-Content -Path 'DBLIST_ACTIONS.TXT'
Run-Workflow -listofservers ($list)

