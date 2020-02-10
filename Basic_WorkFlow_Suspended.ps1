# Basic_WorkFlow_Suspended.ps1 - uses Basic_WorkFlow_CodeBlocks.ps1
# version in c:\codecamp, from Basic_WorkFlow.ps1 
# Last modified: 1/9/2020 (adds Suspend-Workflow)

# Preventive maintenance for testing 
Write-Output "Killing existing jobs . . ."
Get-Job | Remove-Job -Force
Write-Output "Done."
Write-Output " "


workflow RunTasks
 {	
   param($computers) # we pass a list of computers

   InlineScript #1
   {
        Write-Output "Process starts"
        Write-Output (get-date).tostring()
        Write-Output "Task before the parallel process - delete existing csv files"
        $WORKFOLDER = 'C:\CODECAMP\'
        Remove-Item -Path ($WORKFOLDER + '*.csv')
    }   # end of inlinescript 1

    InlineScript #2
    { 
       Write-Output "Started parallel process - saving db data in files" 
    }	# end of inlinescript 2


    foreach -parallel ($computer in $computers)
   {    # start	of foreach -parallel

        # there are 2 items in the sequence (2 inlinescripts):
        # for each item in the foreach -parallel they will be executed in order 
        sequence 
        {     
                # first sequence item---------------------
                $fsize = InlineScript #3 file generation task
                {
                    #Yes Virginia, we can import functions and codeblocks in WorkFlows					
                    . C:\CODECAMP\Basic_WorkFlow_CodeBlocks.ps1		# brings GetParams, Invoke-SqlCmd3						
                    $server, $db, $file = GetParams ($using:computer)
                    $query = 'select * from Person.Person'
                    $currfile = $WORKFOLDER + $file + '-' + $db + '.csv'
                    # clearing noise for tests of bad connections
                    $ErrorActionPreference = 'SilentlyContinue'
                    $null = (Invoke-Sqlcmd3 $server $db $query) | Export-Csv -Path ($currfile) -NoTypeInformation
                    $filesize = (Get-ChildItem $currfile).Length  
                    return $filesize
                }   # end of inlinescript 3

                # Based on a condition we will suspend the workflow
                if ($fsize -eq 0) { Suspend-Workflow }

                # second sequence item---------------------------    
                InlineScript # 4 compress files
                {
                    . C:\CODECAMP\Basic_WorkFlow_CodeBlocks.ps1 # here needed to bring GetParams                  
                    $server, $db, $file = GetParams ($using:computer)
                    $currfile = $WORKFOLDER + $file + '-' + $db + '.csv'
                    $filesize = (get-itemproperty $currfile).Length 
                    # this works the same as above:
                    # $filesize = (Get-ChildItem $currfile).Length                
                    if($filesize -gt 0) 
                    { 
                        & cmd /c compact /C $currfile 
                    }
                    return $filesize
                }  #end of inline script 4
                  
        }           # end of sequence		
   }	            # end of foreach -parallel

    #    SAVE THIS NOTE   
    #    You cannot resume a workflow from within the workflow

   InlineScript #5 Closing final task, emailing report of processed files
   { 	
     . C:\CODECAMP\Basic_WorkFlow_CodeBlocks.ps1 # brings SendMail	
     Write-Output "Final tasks workflow - emailing report"
    #  $WORKFOLDER = 'C:\CODECAMP\'		
     $lst = Get-ChildItem -Path $WORKFOLDER -Filter "*.csv" #get list of produced files
     $msg = ''
     foreach ($k in $lst)
     {
        #  if ($k.Length -gt 0) { #i n case you want to email only the good files
            $msg = $msg + $k.Name + [char]9 + $k.LastWriteTime + [char]13 + [char]10
        #  }
     }
     $msg = $msg +  [char]13 + [char]10 + 'Emailed at ' + (get-date).tostring()
     SendMail $msg 'jbesada@carnival.com' '' 'WorkFlowProcess@noreply.com' 'Workflow Process Report'			
   } 	    # end of inlinescript 5	
   
}		    # end workflow

Write-Output "Time before executing workflow"
Write-Output (get-date).tostring()
Write-Output " "
Write-Output "Now the workflow runs, calling this line:"
Write-Output "RunTasks -computers computer1, computer2, etc"
Write-Output "------workflow starts------------------------ "

# For those of us testing with our little sql server express 
# RunTasks -computers '(localdb)\MSSQLLocalDB|AdventureWorks2008R2','(localdb)\MSSQLLocalDB|AdventureWorks2008R2_A','(localdb)\MSSQLLocalDB|AdventureWorks2008R2_B','(localdb)\MSSQLLocalDB|AdventureWorks2008R2_C'


# this line will cause a workflow suspension (one bad server name)
RunTasks -computers 'CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_Ax','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_B','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_CX'

# this line has no errors, there will be no workflow suspension
# RunTasks -computers 'CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_A','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_B','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_C'


Write-Output "------workflow ends-------------------------- "
Write-Output " "
Write-Output "Time after executing workflow"
Write-Output (get-date).tostring()


Write-Output "Now we run any suspended job: this will restart the workflow from where it was suspended "

# SAVE THIS LINE 
Get-Job -State Suspended | Resume-Job -Wait| Wait-Job


Write-Output "Time after resuming workflow"
Write-Output (get-date).tostring()




