
# Basic_WorkFlow.ps1 - uses Basic_WorkFlow_CodeBlocks.ps1

workflow RunTasks
 {	
   param($computers) # we pass a list of computers
   InlineScript 
   { 
     Write-Output "Task before the parallel process - delete existing csv files"
     $WORKFOLDER = 'C:\Users\jorgebe\Documents\OneDrive\Briefcase_CCL\PASS2019\'
     Remove-Item -Path ($WORKFOLDER + '*.csv')
   }	
   InlineScript { Write-Output "Started parallel process - saving db data in files"}
	
   foreach –parallel ($computer in $computers)
   {	
     sequence
     {
       InlineScript # file generation task
       {
         #Yes Virginia, we can import functions and codeblocks in WorkFlows, calling Invoke-Sqlcmd3					
         . C:\Users\jorgebe\Documents\OneDrive\Briefcase_CCL\PASS2019\Basic_WorkFlow_CodeBlocks.ps1								
         $WORKFOLDER = 'C:\Users\jorgebe\Documents\OneDrive\Briefcase_CCL\PASS2019\'
         Write-Output ("computer:" + $using:computer)
         $server, $db, $file = GetParams ($using:computer)
         $query = 'select * from Person.Person'
         $currfile = $WORKFOLDER + $file + '-' + $db + '.csv'
				
         (Invoke-Sqlcmd3 $server $db $query) | Export-Csv -Path ($currfile) -NoTypeInformation 
       }	#end of inlinescript 1	
			
       InlineScript # file compression task
       {
         . C:\Users\jorgebe\Documents\OneDrive\Briefcase_CCL\PASS2019\Basic_WorkFlow_CodeBlocks.ps1				
         $WORKFOLDER = 'C:\Users\jorgebe\Documents\OneDrive\Briefcase_CCL\PASS2019\'			
         $server, $db, $file = GetParams ($using:computer)
         $currfile = $WORKFOLDER + $file + '-' + $db + '.csv'
         Write-Output ("currfile:" + $currfile)
         & cmd /c compact /C $currfile
									
       } 	# end of inlinescript 2		
     }	  # end of sequence		
   }		  # end of foreach
	
   InlineScript { Write-Output "End of parallel process"}	
   InlineScript # Closing final task, emailing report of processed files
   { 	
     . C:\Users\jorgebe\Documents\OneDrive\Briefcase_CCL\PASS2019\Basic_WorkFlow_CodeBlocks.ps1 # brings SendMail	
     Write-Output "Final tasks workflow - emailing report"
     $WORKFOLDER = 'C:\Users\jorgebe\Documents\OneDrive\Briefcase_CCL\PASS2019\'		
     $lst = Get-ChildItem -Path $WORKFOLDER -Filter "*.csv" #get list of produced files
     $msg = ''
     foreach ($k in $lst)
     {
       $msg = $msg + $k.Name + [char]9 + $k.LastWriteTime + [char]13 + [char]10
     }
     SendMail $msg 'jbesada@carnival.com' '' 'WorkFlowProcess@noreply.com' 'Workflow Process Report'			
   } 	    # end of inlinescript 3	
 }			  # end workflow

RunTasks -computers 'CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_A','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_B','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_C'