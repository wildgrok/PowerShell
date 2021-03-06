﻿#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   4/11/2019 10:42 AM
#Last modified: 5/24/2019 added CheckPing
# Created by:   jorgebe
# Organization: 
# Filename:     
#========================================================================

# Chad Millers Invoke-Sqlcmd3
function Invoke-Sqlcmd3 ($ServerInstance,$Query, $Database)
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
        $ds
    	$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    	[void]$da.fill($ds)
    	$conn.Close()
    	$ds.Tables[0]
	}
}

$ExecuteSQL = 
{	
	param ($ServerInstance, $Query, $Database)
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

function CheckPing($server)
{
	$v = (ping $server -n 1)
	foreach ($k in $v)
	{
		if ($k.StartsWith("Reply"))
		{
			break
		}
		else
		{
			if ($k.StartsWith("Request timed out"))
			{
				return ""
			}		
		}
	}
	$l = $k.Replace('<', '=')
	$lst = $l.split('=')[2]
	if ($lst)
	{
		$r = $lst.Replace('ms TTL', '')
	}
	else
	{
		$r = ""
	}		
	return $r		
}