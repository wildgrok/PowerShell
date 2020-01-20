# Basic_WorkFlow_CodeBlocks.ps1 - used by Basic_WorkFlow.ps1   
# There is method in the madness: put your scriptblocks and functions here
$WORKFOLDER = 'C:\CODECAMP\'
function Invoke-Sqlcmd3 ($ServerInstance,$Database, $Query) # Chad Miller's Invoke-Sqlcmd3
{
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
function SendMail ($report,$emailarray,$attacharray,$from,$subject)
{
	$smtpServer = "smtphost.carnival.com"
	$msg  = new-object Net.Mail.MailMessage
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
