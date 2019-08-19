
# Basic_WorkFlow.ps1 - uses Basic_WorkFlow_CodeBlocks.ps1

workflow RunTasks #Sample Swiss Army knife for all your Workflow needs
 {	
   param($computers) # we pass a list of computers
   InlineScript 
   { 
      #Execute preliminary actions here
   }	
   
   foreach –parallel ($computer in $computers)
   {	
     sequence
     {
       InlineScript
       {
       
          # Actions that must occur first
          
       }	# end of inlinescript 1
			
       InlineScript 
       {
          # Actions that must occur later
									
       } 	# end of inlinescript 2
       		
     }	  # end of sequence		
   }		  # end of foreach
	  
   InlineScript
   { 	
    
          # Closing actions         
    	
   } 	    # end of inlinescript 3	
 }			  # end of workflow

RunTasks -computers 'computer1, computer2, computer3, computer4'