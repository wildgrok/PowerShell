# Basic_WorkFlow.ps1 - uses Basic_WorkFlow_CodeBlocks.ps1
workflow RunTasks
 {	
   param($computers) # we pass a list of computers|databases
   InlineScript 
   {   
      "Task before the parallel process - delete existing csv files"
      $WORKFOLDER = 'C:\WORKFLOWS\' # this is ok, we did not import the file
      Remove-Item -Path ($WORKFOLDER + '*.csv')
   }	
   InlineScript { "Started parallel process - saving db data in files"}
	
   foreach –parallel ($computer in $computers)
   {	
      sequence 
      {     
        $crf = InlineScript # file generation task, first sequence item
        {
            #Yes Virginia, we can import functions and codeblocks in WorkFlows					
            . C:\WORKFLOWS\Basic_WorkFlow_CodeBlocks.ps1		# brings GetParams, Invoke-SqlCmd3						
            $server, $db = GetParams ($using:computer)
            $query = 'select * from Person.Person'
            $currfile = $WORKFOLDER + $server.replace("\", '-') + '-' + $db + '.csv'
            $ErrorActionPreference = 'SilentlyContinue'
            (Invoke-Sqlcmd3 $server $db $query) | Export-Csv -Path ($currfile) -NoTypeInformation 
            return $currfile
        }
          # within the sequence the file will be compressed after it is created   
        InlineScript # compress files, second sequence item
        {
            $filesize = (get-itemproperty ($using:crf)).Length                  
            if($filesize -gt 0) 
            {
                 & cmd /c compact /C ($using:crf)      
            }
            
        }   # end of inline script                 
      }     # end of sequence		
   }	    # end of foreach -parallel
    
   InlineScript # Closing final task, emailing report of processed files
   { 	
     . C:\WORKFLOWS\Basic_WorkFlow_CodeBlocks.ps1 # brings SendMail	
        "Final tasks workflow - emailing report"	
        $lst = Get-ChildItem -Path $WORKFOLDER -Filter "*.csv" #get list of produced files
        $msg = ''
        foreach ($k in $lst)
        {
            if ($k.Length -gt 0)
            {
                $msg = $msg + $k.Name + [char]9 + $k.LastWriteTime + [char]13 + [char]10
            }
        }
        $msg = $msg +  [char]13 + [char]10 + 'Emailed at ' + (get-date).tostring()
        SendMail $msg 'jbesada@carnival.com' '' 'WorkFlowProcess@noreply.com' 'Workflow Process Report'			
   } 	    # end of inlinescript 	
 }		    # end workflow
"Now the workflow runs, calling this line: RunTasks -computers computer1, computer2, etc"
"------workflow starts------------------------ "
RunTasks -computers 'SQLSERVER|AdventureWorks2008R2','SQLSERVER|AdventureWorks2008R2_A','SQLSERVER|AdventureWorks2008R2_B','SQLSERVER|AdventureWorks2008R2_C'
"------workflow ends-------------------------- "

