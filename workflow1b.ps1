#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   4/2/2019 11:06 AM
# Created by:   jorgebe
# Organization: 
# Filename:     
#========================================================================


workflow paralleltest 
{
		#this does not work
		#Write-Host "Started process of parallel"
		InlineScript { Write-Output "Started process of parallel"}
		
		parallel 
		{
	
	 		InlineScript 
			{
			# Imports
. C:\Users\jorgebe\Documents\powershell\WorkFlows\WorkFlows_CodeBlocks.ps1
<#			
			#There is method in the madness: put your codeblock and functions here
				#-------------Codeblocks Start----------------------------------------
				$ExecuteSQL = 
				{
					param ($ServerInstance, $Query, $Database)
					[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") 			| Out-Null
#					[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") 	| Out-Null
#					[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") 		| Out-Null
#					[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") 				| Out-Null
				
					
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
			

#				function Invoke-Sqlcmd3 ($ServerInstance,$Query, $Database)
				function Invoke-Sqlcmd3 ($ServerInstance,$Query)
				{
					[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") 			| Out-Null
#					[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") 	| Out-Null
#					[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") 		| Out-Null
#					[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") 				| Out-Null

					$QueryTimeout=600
				    $conn=new-object System.Data.SqlClient.SQLConnection
#					$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True;database=" + $Database
					$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True"
					$conn.ConnectionString=$constring
				    $conn.Open()
					if($conn)
				    {
				    	$cmd=new-object System.Data.SqlClient.SqlCommand($Query,$conn)
				    	$cmd.CommandTimeout=$QueryTimeout
				    	$ds=New-Object System.Data.DataSet
				        $ds
				    	$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
				    	[void]$da.fill($ds)
				    	$conn.Close()
				    	$ds.Tables[0]
					}
				}	
				function SendMail ($report,$emailarray,$attacharray,$from,$subject)
				{
				    $smtpServer = "smtphost.carnival.com"
				    $msg = new-object Net.Mail.MailMessage
				    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
				    $msg.From = $from      
				    foreach ($c in $emailarray)
				    {  
				        $msg.To.Add($c)
				    }  					
					if ($attacharray -gt '')
					{
				    	$attlist = $attacharray.Split(";")										
						foreach ($c in $attlist)
					    { 
					        $att = new-object Net.Mail.Attachment($c)
					        $msg.Attachments.Add($att)
					    }
					}					
				    $msg.Subject = $subject
				    $msg.Body = $report
				    $smtp.Send($msg)
				}

				#-------------Codeblocks End----------------------------------------
#>				
				
		   Set-Content -Path 'C:\Users\jorgebe\Documents\powershell\WorkFlows\out.txt' (Invoke-Sqlcmd3 'CCLDEVSHRDDB1\DEVSQL2' 'select name from master.dbo.sysdatabases').name
#		   Get-CimInstance –ClassName Win32_OperatingSystem
		   Get-Process –Name PowerShell*
#		   Get-CimInstance –ClassName Win32_ComputerSystem
		   Get-Service –Name s*			
#			(Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_GetServers, "master"))
			Set-Content -Path 'C:\Users\jorgebe\Documents\powershell\WorkFlows\out2.txt' (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ('CCLTSTSQL1\TSTSQL3', 'select name from master.dbo.sysdatabases', "master")).name

	  	}	# end of inline script	
	}		# end of parallel
	#Same as before, no write-host
	#Write-Host "Completed process of parallel"
	#this happens after the parallel operations
	InlineScript { Write-Output "Completed process of parallel"}
	#After we collected all the outputs of the parallel processes we can use the them
	#In this case we are compressing all the files and emailing them
	#"this does not work
	#Dot-sourcing (. <command>) and the invocation operator (& <command>) are not 
	#supported in a Windows PowerShell Workflow. Wrap this command invocation into 
	#an inlinescript { } instead.
	#& cmd /c "compact /C " "C:\Users\jorgebe\Documents\powershell\WorkFlows\AdventureWorks_Sales.csv"
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
		& cmd /c 'compact /U ' $attachment
	}
	
}

paralleltest