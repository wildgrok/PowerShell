#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   7/5/2019 4:53 PM
# Created by:   jorgebe
# Organization: 
# Filename:     
#========================================================================

#There is method in the madness: put your codeblock and functions here
#-------------Codeblocks Start----------------------------------------
$ExecuteSQL = 
{
	param ($ServerInstance, $Query, $Database)
		
	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") 			| Out-Null
#	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") 	| Out-Null
#	[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") 		| Out-Null
#	[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") 				| Out-Null
				
					
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
			
#function Invoke-Sqlcmd3 ($ServerInstance,$Query)
function Invoke-Sqlcmd3 ($ServerInstance,$Database, $Query)
{
	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") 			| Out-Null
#	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") 	| Out-Null
#	[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") 		| Out-Null
#	[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") 				| Out-Null

	$QueryTimeout=600
	$conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True;database=" + $Database
#	$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True"
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

function GetParams ($indata)
{
	$k = $indata.Split("|")
	$server = $k[0]
	$db = $k[1]
	$file = $server.replace("\", '-')
	return $server, $db, $file
}

#-------------Codeblocks End----------------------------------------