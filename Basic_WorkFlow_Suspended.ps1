# Basic_WorkFlow_Suspended.ps1 - uses Basic_WorkFlow_CodeBlocks.ps1

"Killing existing jobs . . ."   # Preventive maintenance  
Get-Job | Remove-Job -Force
"Done."
" "
workflow RunTasks
 {	
   param($computers) # we pass a list of computers|databases

   InlineScript #1
   {
        "Process starts"
        (get-date).tostring()
        "Task before the parallel process - delete existing csv files"
        $WORKFOLDER = 'C:\WORKFLOWS\'
        Remove-Item -Path ($WORKFOLDER + '*.csv')
    }   # end of inlinescript 1

    InlineScript #2
    { 
       "Started parallel process - saving db data in files" 
    }	# end of inlinescript 2


    foreach -parallel ($computer in $computers)
   {    # start	of foreach -parallel

        # there are 2 items in the sequence (2 inlinescripts):
        # for each item in the foreach -parallel they will be executed in order 
        sequence 
        {     
            # first sequence item---------------------
            $currf = InlineScript #3 file generation task
            {
                #Yes Virginia, we can import functions and codeblocks in WorkFlows					
                . C:\WORKFLOWS\Basic_WorkFlow_CodeBlocks.ps1		# brings GetParams, Invoke-SqlCmd3
                $query = 'select * from Person.Person'						
                $server, $db = GetParams ($using:computer)
                $currfile = $WORKFOLDER + $server.replace("\", '-') + '-' + $db + '.csv'  

                # clearing noise for tests of bad connections
                $ErrorActionPreference = 'SilentlyContinue'
                $null = (Invoke-Sqlcmd3 $server $db $query) | Export-Csv -Path ($currfile) -NoTypeInformation
                $filesize = (Get-ChildItem $currfile).Length                 
                # return currfile|size
                return ($currfile + "|" + $filesize.ToString())
             }   # end of inlinescript 3---------------------

            # Based on a condition we will suspend the workflow
            # WORKFLOW IS SUSPENDED ONLY FOR THE CURRENT ITEM 
            $a = $currf.Split("|")
            if ($a[1] -eq '0') 
            { 
                "Zero length file!"
                $a[0]
                Suspend-Workflow 
            }
       
            # second sequence item---------------------------    
            InlineScript # 4 compress files
            {
                $file = ($using:currf).Split("|")[0]
                & cmd /c compact /C $file # compressing the file
            }  #end of inline script 4-----------------------
                  
        }   # end of sequence		
   }	    # end of foreach -parallel

    #    SAVE THIS NOTE: You cannot resume a workflow from within the workflow

   InlineScript #5 Closing final task, emailing report of processed files
   { 	
     . C:\WORKFLOWS\Basic_WorkFlow_CodeBlocks.ps1 # brings SendMail	and $WORKFOLDER 
     "Final tasks workflow - emailing report"		
     $lst = Get-ChildItem -Path $WORKFOLDER -Filter "*.csv" #get list of produced files
     $msg = ''
     foreach ($k in $lst)
     {
          if ($k.Length -gt 0) { # in case you want to email only the good files
            $msg = $msg + $k.Name + [char]9 + $k.LastWriteTime + [char]13 + [char]10
          }
     }
     $msg = $msg +  [char]13 + [char]10 + 'Emailed at ' + (get-date).tostring()
     SendMail $msg 'jbesada@carnival.com' '' 'WorkFlowProcess@noreply.com' 'Workflow Process Report'			
   } 	    # end of inlinescript 5	   
}		    # end workflow

#---------EXECUTION STARTS HERE--------------------------------
Set-Location C:\WORKFLOWS
$list = (Get-Content -Path 'LIST_OF_SERVERS_AND_DBS.TXT')
"Time before executing workflow"
(get-date).tostring()
"Now the workflow runs, calling this line:"
"RunTasks -computers (list of computer|db lines)"
"------workflow starts------------------------ "
RunTasks -computers ($list)
"------workflow ends-------------------------- "
"Time after executing workflow"
(get-date).tostring()





