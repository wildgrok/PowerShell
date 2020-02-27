workflow RunTasks
 {	
    param($computers) # we pass a list of computers|databases
    InlineScript #1
    {
        "Process starts, task before the parallel process - delete existing csv files"       
        $WORKFOLDER = 'C:\CODECAMP\'
        Remove-Item -Path ($WORKFOLDER + '*.csv')
    }   # end of inlinescript 1

    InlineScript #2
    { "Started parallel process - saving db data in files" }	# end of inlinescript 2

    foreach -parallel ($computer in $computers)
    {    # start	of foreach -parallel
        sequence 
        {     
            $currf = InlineScript #3 first sequence item, file generation task
            {					
                . C:\CODECAMP\Basic_WorkFlow_CodeBlocks.ps1		# brings GetParams, Invoke-SqlCmd3
                $query = 'select * from Person.Person'						
                $server, $db = GetParams ($using:computer)
                $currfile = $WORKFOLDER + $server.replace("\", '-') + '-' + $db + '.csv'  
                (Invoke-Sqlcmd3 $server $db $query) | Export-Csv -Path ($currfile) -NoTypeInformation
                $filesize = (Get-ChildItem $currfile).Length                 
                return ($currfile + "|" + $filesize.ToString()) # return currfile|size
             }   # end of inlinescript 3---------------------

            # Based on a condition we will suspend the workflow
            # WORKFLOW IS SUSPENDED ONLY FOR THE CURRENT ITEM 
            $a = $currf.Split("|")
            if ($a[1] -eq '0') 
            {  "Zero length file!"
                $a[0]
                Suspend-Workflow 
            }       
               
            InlineScript # 4 second sequence item, compress files
            { $file = ($using:currf).Split("|")[0]
              & cmd /c compact /C $file            # compressing the file
            }  # end of inline script 4---------------------------------                 
        }      # end of sequence		
   }	         # end of foreach -parallel
    #    SAVE THIS NOTE: You cannot resume a workflow from within the workflow
   InlineScript #5 Closing final task, emailing report of processed files
   { 	
     . C:\CODECAMP\Basic_WorkFlow_CodeBlocks.ps1 # brings SendMail	and $WORKFOLDER 
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
   } 	  # end of inlinescript 5	   
}		    # end workflow
#---------EXECUTION STARTS HERE--------------------------------
Set-Location C:\CODECAMP
$list = (Get-Content -Path 'LIST_OF_SERVERS_AND_DBS.TXT')
(get-date).tostring()
"Now the workflow runs, calling this line: RunTasks -computers (list of computer|db lines)"
"------workflow starts------------------------ "
RunTasks -computers ($list)
"------workflow ends-------------------------- "
(get-date).tostring()





