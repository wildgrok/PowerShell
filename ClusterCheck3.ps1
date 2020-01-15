<#
ClusterCheck3.ps1
Test version for checking IP addresses in cluster
Last change:
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

function Invoke-Sqlcmd3 ($ServerInstance,$Query, $Database)
#function Invoke-Sqlcmd3 ($ServerInstance,$Query)
<#
	Chad Millers Invoke-Sqlcmd3
#>
{
	$QueryTimeout=600
    $conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True;database=" + $Database
#    $constring = "Server=" + $ServerInstance + ";Trusted_Connection=True"
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


#====================Program start======================================
$SERVERNAME = "CCLDEVSHRDDB1\DEVSQL2"
#$path = Get-Location
$CLUSTERNAMES = "ccldceshrdcl1", "ccluatdtscl2", "ccluatdtscl4", "CCLUATSBLCL1", "CCLUATINFSHCL1", "ccluatshrd2cl1"
#$CLUSTERNAMES = "CCLUATSBLCL1"
$clusterset = @{}

#truncate table first
Invoke-Sqlcmd3 $SERVERNAME "truncate table Master_Application_List.[dbo].[CLUSTERS]" "master"
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
            Invoke-Sqlcmd3 $SERVERNAME $sql "master"
        }
    }
}

#test print
$clusterset
