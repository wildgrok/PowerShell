#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   4/2/2019 11:06 AM
# Created by:   jorgebe
# Organization: 
# Filename: 
#https://devblogs.microsoft.com/scripting/powershell-workflows-the-basics/
#========================================================================


workflow RunTasks
{
	
	param([string[]]$computers)
	#this does not work
	#Write-Host "Started process of parallel"
	<#
	If you want a set of commands to execute in parallel, 
	all you need to do is add the parallel keyword 
	and the code between the brackets {} will be executed in parallel.
	In which order do you think the data will be returned?
	You can’t tell! You can run this workflow a number of times 
	and the data may be returned in a different order each time you run it!
	#>
	
	InlineScript { Write-Output "Started process of parallel"}
	<#
	You can use the Parallel keyword to create a script block with multiple commands 
	that will run concurrently. This uses the syntax shown below. 
	In this case, Activity1 and Activity2 will start at the same time. 
	Activity3 will start only after both Activity1 and Activity2 have completed.
	Parallel
	{
	  <Activity1>
	  <Activity2>
	}
	<Activity3>
	#>
	<#
	   param([string[]]$computers)
   foreach –parallel ($computer in $computers){

	#>
	
	foreach –parallel ($computer in $computers)
	{				
	 	InlineScript 
		{
			$WORKFOLDER = 'C:\Users\jorgebe\Documents\powershell\WorkFlows\'			
			function Invoke-Sqlcmd3 ($ServerInstance, $Database, $Query)
			{
				[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") 	| Out-Null
				$QueryTimeout=600
				$conn=new-object System.Data.SqlClient.SQLConnection
				$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True;database=" + $Database
				$conn.ConnectionString=$constring
				$conn.Open()
				if($conn)
				{
					$cmd=new-object System.Data.SqlClient.SqlCommand($Query,$conn)
					$cmd.CommandTimeout=$QueryTimeout
					$ds=New-Object System.Data.DataSet
					$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
					[void]$da.fill($ds)
					$conn.Close()
					$ds.Tables[0]
				}
			}	
			
			function GetParams ($indata)
			{
				$k = $indata.Split("|")
				$server = $k[0]
				$db = $k[1]
				$file = $server.replace("\", '-')
				return $server, $db, $file
			}
			

			$server, $db, $file = GetParams ($using:computer)
			$query = 'select * from Person.Person'
			(Invoke-Sqlcmd3 $server $db $query) | Export-Csv -Path ($WORKFOLDER + $file + '-' + $db + '.csv') -NoTypeInformation
					
		} 	# end of inlinescript
		sequence 
		{
			InlineScript { Write-Output $using:computer}
		}
		
	}		# end of foreach
	
}			# end workflow
	#Same as before, no write-host
	#Write-Host "Completed process of parallel"
	#this happens after the parallel operations
#	InlineScript { Write-Output "Completed process of parallel"}
	#After we collected all the outputs of the parallel processes we can use them
	#In this case we are compressing all the files and emailing them
	#"this does not work
	#Dot-sourcing (. <command>) and the invocation operator (& <command>) are not 
	#supported in a Windows PowerShell Workflow. Wrap this command invocation into 
	#an inlinescript { } instead.
	#& cmd /c "compact /C " "C:\Users\jorgebe\Documents\powershell\WorkFlows\AdventureWorks_Sales.csv"
	<#
	InlineScript 
	{ 
		$attachment = 'C:\Users\jorgebe\Documents\powershell\WorkFlows\AdventureWorks_Sales.csv'
		& cmd /c 'compact /C ' $attachment
		#SendMail ($report,$emailarray,$attacharray,$from,$subject)
		#No good, as expected
		#SendMail : The term 'SendMail' is not recognized as the name of a cmdlet, 
		#function, script file, or operable program. Check the spelling of the name, or 
		#if a path was included, verify that the path is correct and try again.
		#SendMail ($report,'jbesada@carnival.com',$attachment,'WorkflowMaster@carnival.com','Compressed files')
		#this works
. C:\Users\jorgebe\Documents\powershell\WorkFlows\WorkFlows_CodeBlocks.ps1
		SendMail "Compressed file included" 'jbesada@carnival.com' $attachment 'WorkflowMaster@carnival.com' 'Compressed files'
		#included for repeated testing
		#& cmd /c 'compact /U ' $attachment
	}
	#>


RunTasks -computers 'CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_A','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_B','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_C'