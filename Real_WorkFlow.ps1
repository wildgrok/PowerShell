#Real_WorkFlow.ps1 - uses Real_Workflow_CodeBlocks.ps1

workflow Run-Workflow 
{ # start of workflow
  param($listofservers)  
    InlineScript
    {
      "Parallel process to start . . ."    
    }

    foreach -parallel ($k in $listofservers)
    {
       
      sequence
      {
        InlineScript
        {
          "Executing first sequence items ..."
          . C:\WORKFLOWS\Real_Workflow_CodeBlocks.ps1
          $a = ($using:k).Split('|')
          $SOURCESERVER,$BACKUPFILE,$SOURCEDB,$DESTSERVER = $a[0],$a[1],$a[2],$a[3]
          $DATAFOLDER,$LOGFOLDER,$DESTDB,$ACTIONS         = $a[4],$a[5],$a[6],$a[7]      	
          $restore_options = @{}				
          	
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
                                       	        
        } # end of inlinescript 1
        
        InlineScript
        {
          "Executing second sequence items ..." 
        } # end of inlinescript 2
      }   # end of sequence 
    }     # end of foreach
    
    InlineScript
    {
      "Parallel process completed . . ."    
    }         
}         # end of workflow	

Set-Location C:\WORKFLOWS
$list = (Get-Content -Path 'DBLIST_ACTIONS.TXT' | where { $_.Contains("|Y") })
Run-Workflow -listofservers ($list)

