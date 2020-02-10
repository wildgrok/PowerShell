# Swiss_Army_Knife.ps1 
# Sample Swiss Army knife for all your Workflow needs

workflow RunTasks 
 {	
   param($computers) # we pass a list of computers
   InlineScript # 1
   { 
      # Execute preliminary actions here
   }	
   
   # this is it
   foreach –parallel ($computer in $computers)
   {	
     sequence
     {
       InlineScript # 2
       {
          # Actions that must occur first    
       }	# end of inlinescript 2
			
       InlineScript  # 3
       {
          # Actions that must occur later									
       } 	# end of inlinescript 3
       		
     }	  # end of sequence		
   }		  # end of foreach
	  
   InlineScript # 4
   { 	   
          # Closing actions after the parallel part           	
   } 	    # end of inlinescript 4

 }			  # end of workflow

# Executing the workflow
RunTasks -computers 'computer1, computer2, computer3, computer4'




