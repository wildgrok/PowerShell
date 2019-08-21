#SQLSMO_WorkFlow.ps1
#version in work PC
#C:\Users\jorgebe\Documents\powershell\workflows
#Uses SQLSMO_WorkFlow_CodeBlocks.ps1 to import 
#Called from SQLSMO_WorkFlow.cmd
#Created 8/1/2019
#Last modified:
#8/21/2019: tested conversion from fake workflow to real workflow

#=========================PROGRAM STARTS===========================================
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
        . C:\Users\jorgebe\Documents\powershell\workflows\SQLSMO_Workflow_CodeBlocks.ps1
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



Set-Location C:\Users\jorgebe\Documents\powershell\workflows
$list = Get-Content -Path 'DBLIST_ACTIONS_SQLSMO.TXT'

Run-Workflow -listofservers ($list)

