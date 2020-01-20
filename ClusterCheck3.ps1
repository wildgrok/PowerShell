<#
ClusterCheck3.ps1
Test version for checking IP addresses in cluster
Last change:
1/17/2020: started to add back population of AG_IPADDRESS_CHECK
1/15/2020: added these clusters "CCLUATINFSHCL1", "ccluatshrd2cl1"
5/29/2019: moved to \\CCLDEVSHRDDB1\e$\POWERSHELL
11/9/2018: added checkping for the IP addresses

Sources:
https://www.howtogeek.com/117192/how-to-run-powershell-commands-on-remote-computers/
https://kb.paessler.com/en/topic/69793-run-powershell-script-remotely-but-not-exchange-server
https://social.technet.microsoft.com/Forums/en-US/9a55ea6f-d20a-436a-924d-399d84962574/get-a-return-value-from-invokecommand?forum=winserverpowershell
https://docs.microsoft.com/en-us/powershell/module/failoverclusters/get-clusterresource?view=win10-ps
#>


function GetClusterResources ($computerName)
{
    $session = New-PSSession -computerName $computername -Authentication Kerberos #-credential $credential 
    $scriptBlock = 
    {
        import-module failoverclusters
        Get-ClusterResource
    }
    
    Invoke-Command -computerName $computername -scriptBlock $scriptBlock
    Remove-PSSession -computerName $computername
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
#$r = CheckPing('172.25.131.71')
#$r


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

#====================Program start======================================
$SERVERNAME = "CCLDEVSHRDDB1\DEVSQL2"
$CLUSTERNAMES = "ccldceshrdcl1", "ccluatdtscl2", "ccluatdtscl4", "CCLUATSBLCL1", "CCLUATINFSHCL1", "ccluatshrd2cl1"

Write-Host "Start time AG and clusters " (get-date)

$clusterset = @{}

#truncate table first
$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, "truncate table Master_Application_List.[dbo].[CLUSTERS]", "master"))
foreach ($h in $CLUSTERNAMES)
{
    $clusterset[$h] = GetClusterResources $h
    foreach ($k in $clusterset[$h])
    {   
        if ($k.ToString().Contains(".") -and $k.ToString().Contains("_"))
        {
            $m = $k.ToString().Replace("_", "|")
            $s = $h + '|' + $m
            $v = $s.Split("|")
            $p = CheckPing($v[2])
            $sql = "INSERT INTO Master_Application_List.[dbo].[CLUSTERS] ([ClusterMachine],[AG_Group],[IP_ADDRESS], [PING_RESPONSE]) VALUES "
            $sql = $sql + "('" + $v[0] + "','" + $v[1]  + "','" + $v[2] +  "','" + $p + "')"
			$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $sql, "master"))			
        }
    }
}


#1/20/2020

$SQL_LIST_AG_IPS = 
@"
SET NOCOUNT ON
select l.dns_name, l.port, ip.ip_address, ip_subnet_mask, ip.state_desc, "Data_Center" =   
      CASE   
        WHEN ip.ip_address LIKE '10.224.%' THEN 'DCE    - Miami'
        WHEN ip.ip_address LIKE '172.25%' THEN 'DCE (NON - PROD) - Miami' 
	    WHEN ip.ip_address LIKE '10.244.%' THEN 'PEAK10 - Invalid' 
	    WHEN ip.ip_address LIKE '10.56.%'  THEN 'DCC    - Dallas' 
        ELSE 'UNKNOWN LOCATION - Invalid' 
      END  
from sys.availability_group_listener_ip_addresses ip  
join sys.availability_group_listeners l on l.listener_id = ip.listener_id
"@

$SQL_Serverlist_AG = "SELECT distinct [Listener Name] + ',' + cast([Port] as varchar(10)) as 'Server' FROM [Master_Application_List].[dbo].[AG SQL Servers]"



# truncate table first
$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, 'truncate table Master_Application_List.[dbo].[AG_IPADDRESS_CHECK]', "master"))
$SERVERLIST = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $SQL_Serverlist_AG, "master"))
foreach ($k in $SERVERLIST)
{
	$svr = [char]34 + $k.Server + [char]34
	$j = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($svr, $SQL_LIST_AG_IPS, "master"))
    foreach ($r in $j)
    {
        $s = "INSERT INTO Master_Application_List.[dbo].[AG_IPADDRESS_CHECK]([dns_name],[port],[ip_address],[ip_subnet_mask],[state_desc],[Data_Center]) VALUES "
        $s = $s + "('" + $r.dns_name + "','" + ,$r.port +  "','" +,$r.ip_address + "','" + $r.ip_subnet_mask + "','" + $r.state_desc + "','" + $r.Data_Center + "')"
		$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $s, "master"))
    }
}
Write-Host "End time AG and clusters " (get-date)

