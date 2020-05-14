#DBATOOL.ps1
#version in CCLDEVSHRDDB1\e$\Powershell
#Based on SQLSMO.ps1, workflow
#Uses DBATOOL_CodeBlocks.ps1, DBATOOL_CodeBlocks2.ps1 contains these calls:
#$ExecuteSQL, $GetBackupInfo, $GetLatestBackup, $GetBackups,  
#Created 9/25/2019 from SQLSMO2.ps1
#Last updated:
#3/25/2020: commented set-location
#11/14/2019: Added option to script only
#9/27/2019: tested updated restoredatabase and restorelogs

#=========================PROGRAM STARTS===========================================
workflow Run-Workflow 
{ # start of workflow
    
    InlineScript #1
    {
        # Set-Location e:\POWERSHELL
        # $ErrorActionPreference = "silentlycontinue"
        cls
        # "Process started " 
        $d1 = Get-Date
        $d1
        " "           
    }      
    
    # populating list from DBLIST_ACTIONS.TXT
    $listofactions = InlineScript #2
    {
        # Set-Location e:\POWERSHELL
        $listofactions = Get-Content -Path 'DBLIST_ACTIONS_MD.TXT'
        return $listofactions       
	}       # end of inlinescript 2
    
    
    #---------------------------
    $out = {}
    foreach -parallel ($k in $listofactions)
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
						
		if (($ENABLED -eq 'Y') -or ($ENABLED -eq 'S')) 
		{				
            if ($ACTIONS -like 'RESTORE_DATABASE_FULL_*')
			{		
                InlineScript
                {
                    # Set-Location e:\POWERSHELL
                    . e:\POWERSHELL\DBATOOL_CodeBlocks2.ps1   
                    $null = (Invoke-Command -ScriptBlock $RestoreDatabase -ArgumentList ($using:k))
    			}
			}
					
			if ($ACTIONS -like 'RESTORE_LOGS_WITH_*')
			{	
                InlineScript
                {
                    # Set-Location e:\POWERSHELL
                    . e:\POWERSHELL\DBATOOL_CodeBlocks2.ps1   
    				$null = (Invoke-Command -ScriptBlock $RestoreLogs -ArgumentList ($using:k))
				}
			}
            
            if ($ACTIONS -like 'SQL_*')
			{	
                InlineScript
                {
                    # Set-Location e:\POWERSHELL
                    . e:\POWERSHELL\DBATOOL_CodeBlocks2.ps1
                    $ErrorActionPreference = "silentlycontinue"
    				(Invoke-Command -ScriptBlock $SQLActions -ArgumentList ($using:k)) 
#                    $r
#                    $out[$using:k] = $r
#                    foreach ($t in $r)
#                   {
#                        $t
#
##                        foreach ($g in $t)
##                        {
##                            $g.ItemArray
##						}
#					}
				}
			}
					                   
		} # end of if enabled	
    } # end of foreach -parallel
    #---------------------------
#    $out
    
#    foreach ($k in $out)
#    {
#        $k.Name
##        $k.Value
#        foreach ($M in $k.Value)
#        {
#            $M
#		}
#            
#	}
} # end of workflow	
Run-Workflow 
#$x = Run-Workflow 
#$x > 'DBATOOL.OUT'
#Set-Location e:\POWERSHELL
#
#Set-Content 'DBATOOL.OUT' ''
#foreach ($k in $x)
#{
#    Add-Content 'DBATOOL.OUT' $k
#}


