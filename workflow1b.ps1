#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   4/2/2019 11:06 AM
# Last modified 7/15/2019
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
	
	InlineScript 
	{ 
		Write-Output "Task before the parallel process - delete existing csv files"
		$WORKFOLDER = 'C:\Users\jorgebe\Documents\powershell\WorkFlows\'
		Remove-Item -Path ($WORKFOLDER + '*.csv')
	}
	
	InlineScript { Write-Output "Started parallel process - saving db data in files"}
	
	foreach –parallel ($computer in $computers)
	{	
		sequence
		{
	 	InlineScript # file generation task
		{
					
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
			
			$WORKFOLDER = 'C:\Users\jorgebe\Documents\powershell\WorkFlows\'
			Write-Output $using:computer
			$server, $db, $file = GetParams ($using:computer)
			$query = 'select * from Person.Person'
			$currfile = $WORKFOLDER + $file + '-' + $db + '.csv'
			
			(Invoke-Sqlcmd3 $server $db $query) | Export-Csv -Path ($currfile) -NoTypeInformation 
		}	#end of inlinescript 1	
			
		InlineScript # file compression task
		{			
			function GetParams ($indata)
			{
				$k = $indata.Split("|")
				$server = $k[0]
				$db = $k[1]
				$file = $server.replace("\", '-')
				return $server, $db, $file
			}
			
			$WORKFOLDER = 'C:\Users\jorgebe\Documents\powershell\WorkFlows\'			
			$server, $db, $file = GetParams ($using:computer)
			$currfile = $WORKFOLDER + $file + '-' + $db + '.csv'
			Write-Output "currfile " $currfile
			& cmd /c compact /C $currfile
								
		} 	# end of inlinescript 2		
		}	# end of sequence		
	}		# end of foreach
	
	InlineScript { Write-Output "Completed process of parallel"}
	
	InlineScript 
	{ 
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
		
		
		Write-Output "Final tasks workflow - emailing report"
		$WORKFOLDER = 'C:\Users\jorgebe\Documents\powershell\WorkFlows\'		
		#get list of produced files
		$lst = Get-ChildItem -Path $WORKFOLDER -Filter "*.csv"

		$msg = ''
		foreach ($k in $lst)
		{
			$msg = $msg + $k.Name + [char]9 + $k.LastWriteTime + [char]13 + [char]10
		}
		SendMail $msg 'jbesada@carnival.com' '' 'WorkFlowProcess@noreply.com' 'Workflow Process Report'			
	} 	# end of inlinescript 3	
	
	
}			# end workflow

RunTasks -computers 'CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_A','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_B','CCLDEVSQL4\DEVSQL2|AdventureWorks2008R2_C'