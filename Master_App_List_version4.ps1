<#
Master_app_List_version4.ps1
#version in \\CCLDEVSHRDDB1\e$\POWERSHELL
made from List_DB_Files.ps1
Created: 4/3/2019 out of Master_app_List_version4.ps1
Last updated:
4/8/2019: completed testing with _XXX, changed to regular tables
Backup made Master_App_List_SQL_4_8_2019.ps1 and Master_App_List_version4_4_8_2019.ps1
Run time is 10 mins approx
4/3/2019: testing using  tables _XXX
2/8/2019: added AG Ipaddress check, $GetClusterResources
2/7/2019: added GetServersAndDBs and Missing backups
2/6/2019: added get machine type functionality
2/5/2019: working on adding function calls to insert section, got it with scriptblocks
1/31/2019: fixed insertion part!
1/30/2019: working on jobs fixes


Will create report of all database files from all servers from table with servers
#>
#I:\OPCONJOBS\MasterApplicationList
Set-Location e:\POWERSHELL
# Imports
. e:\POWERSHELL\Master_App_List_SQL.ps1
<#

    $SQL_Reload_EnvironmentsAndApplications
    $SQL_GetSQLServers
    $SQL_GetServers
    $SQL_Get_DBSFromServer
    $SQL_GetMissingFrom_ServersAndDatabases
    $SQL_FixVersionsAndOnlineOffline
    $SQL_UpdateFrom_EnvironmentsAndApplicationsBACKUP
    $SQL_GetLogins
    $SQL_GetUsers
    $SQL_GetBackupInfo
    $SQL_ClearMissingBackupsTable
    $SQL_InsertIntoBackupHistory
    $SQL_Insert_Production_Values
    $SQL_Servers_And_Databases_Compatibility_Differences_Query
    $SQL_Get_Database_Files_Query
 	$SQL_LIST_AG_IPS
	$SQL_Serverlist_AG
#>





#===========================functions and scriptblocks=================================================
<#
#function Invoke-Sqlcmd3 ($ServerInstance,$Query, $Database)
function Invoke-Sqlcmd3 ($ServerInstance,$Query)
# Chad Millers Invoke-Sqlcmd3
{
	$QueryTimeout=600
    $conn=new-object System.Data.SqlClient.SQLConnection
#	$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True;database=" + $Database
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
#>

#Based on Chad Millers Invoke-Sqlcmd3
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

$Fill_All_Logins =
{
#	param ($SC, $l, $global:SERVERNAME)
	param ($SC, $SQL_GetLogins, $global:SERVERNAME)
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
	
	$l = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_GetLogins, "master"))
	
   	foreach($y in $l)
    {
        if ($SC -gt '' -and $y.name -gt '')
        {
            $name = $y.name
		    $dbname = $y.dbname
		    $sysadmin = $y.sysadmin
		    $isntgroup = $y.isntgroup
		    $isntuser = $y.isntuser                
		    $logininsert = "INSERT INTO [Master_Application_List].[dbo].[All Logins] ([SQLSERVER],[name],[dbname],[sysadmin],[isntgroup],[isntuser]) VALUES "
		    $logininsert = $logininsert + " ('" + $SC + "','" + $name + "','" + $dbname + "','" + $sysadmin + "','" + $isntgroup + "','" + $isntuser + "')" 
		    $ErrorActionPreference = "silentlycontinue"
            $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $logininsert, "master"))
        }
    }
}

$Fill_All_Users =
{
#	param ($SC, $usersdb, $global:SERVERNAME)
	param ($SC, $SQL_GetUsers, $global:SERVERNAME)
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
	
	$usersdb = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_GetUsers, "master"))	
   	foreach($uu in $usersdb)
    {
        if ($SC -gt '' -and $uu.UserName -gt '')
        {	
			$dbname = $uu.DBName
			$username = $uu.UserName
			$rolename = $uu.RoleName		
			$userinsert = "INSERT INTO [Master_Application_List].[dbo].[All Users] ([SQLSERVER],[DB Name],[User Name],[Role Name]) VALUES "
			$userinsert = $userinsert + " ('" + $SC + "','" + $dbname + "','" + $username + "','" + $rolename + "')"
			$ErrorActionPreference = "silentlycontinue"
            $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $userinsert, "master"))
		}
    }   
}

$Fill_DB_Files = 
{
#	param ($SC, $d, $global:SERVERNAME)
	param ($SC, $SQL_Get_Database_Files_Query, $global:SERVERNAME)
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
		
#	-ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_Get_Database_Files_Query, "master") 
	$d = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_Get_Database_Files_Query, "master"))
		
   	foreach($y in $d)
	{
       	if ($SC -gt '' -and $y.DatabaseName -gt '')
		{
			$o = $y.DatabaseName
			$v = $y.LogicalFileName
			$h = $y.PhysicalFileName
			$g = $y.Type
			$dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Database Files] ([SQLServer],[DatabaseName],[LogicalFileName],[PhysicalFileName],[Type]) VALUES "
			$dbinsert = $dbinsert + "('" + $SC  + "','" + $o + "','" + $v +  "','" + $h + "','" + $g + "')" 
#			$ErrorActionPreference = "silentlycontinue"
            $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $dbinsert, "master"))
		}
   	}
}

$Fill_Server_And_DBs = 
{
	param ($SC, $SQL_Get_DBSFromServer, $global:SERVERNAME)
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
	
	$svrdbs = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_Get_DBSFromServer, "master"))
	
	foreach ($y in $svrdbs)
	{
		$n = $y.name
		if ($n -gt '')
		{
			$o = $y.Online_Offline
			$v = $y.SqlVersion
			$dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Servers and Databases] ([SQLServer],[Database_Name],[Online_Offline],[SqlVersion])VALUES"
			$dbinsert = $dbinsert + "('" + $SC + "','" + $n + "','" + $o + "','" + $v + "')" # + [char]13 + [char]10 + 'GO' + [char]13 + [char]10  THIS IS THE FIX 8/1/2017
	#		# needed for servers with no access
			$ErrorActionPreference = "silentlycontinue"
			$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $dbinsert, "master"))
		}
	}	
}

$Fill_Missing_Backups = 
{
	param ($SC, $SQL_GetBackupInfo, $global:SERVERNAME)
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
	
	$msbkp = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_GetBackupInfo, "master"))

	foreach ($y in $msbkp)
	{
		$db = $y.db
		if ($db -gt '')
		{
			$dt = $y.bkdate
	#		$svr = [char]39 + [char]34 + $scurr + [char]34 + [char]39
			$s = "INSERT INTO [Master_Application_List].[dbo].[Missing Backups]([SqlServer],[DBname],[BKDate]) VALUES ('"
			$s = $s + $SC + "','" + $db + "','" + $dt + "')"
			$ErrorActionPreference = "silentlycontinue"
			$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $s, "master"))
		}
	}	
}



$CheckPing = 
{
	param ($server, $global:SERVERNAME)
	
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
	
	$v = (ping $server -n 1)
	foreach ($k in $v)
	{
		if ($k.StartsWith("Reply"))
		{ break }
		else
		{ if ($k.StartsWith("Request timed out")) { return "" }	}
	}
	$l = $k.Replace('<', '=')
	$lst = $l.split('=')[2]
	if ($lst)
	{ $ping = $lst.Replace('ms TTL', '') }
	else { $ping = "" }		
    $p = $ping.Trim()
    $p2 = [int]$p
    if ($p -gt "")  
    {
        $s = "INSERT INTO [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY] (Machine) VALUES ('" + $server + "')"		
    }
    else
    {
        $s = "INSERT INTO [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY] (Machine, Status) VALUES ('" + $server+ "', 'DEAD TODAY')"
    }
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $s, "master"))	
}


#Original created by: Jason Wasser
#Modified: 4/20/2017 03:28:53 PM 
#https://gallery.technet.microsoft.com/scriptcenter/Get-MachineType-VM-or-ff43f3a9
#version changed for scriptblock and simplified
$GetMachineType =
{
#	param($Computer)
	param($Computer, $global:SERVERNAME)
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
	
	$ErrorActionPreference = "silentlycontinue"
	$Credential = [System.Management.Automation.PSCredential]::Empty

    # Check to see if $Computer resolves DNS lookup successfuly.
    $null = [System.Net.DNS]::GetHostEntry($Computer)
   	$ComputerSystemInfo = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $Computer -ErrorAction silentlycontinue -Credential $Credential           
    switch ($ComputerSystemInfo.Model) 
	{                  
        # Check for Hyper-V Machine Type
        "Virtual Machine" 			{ $MachineType="VM" }
        # Check for VMware Machine Type
        "VMware Virtual Platform" 	{ $MachineType="VM" }
        # Check for Oracle VM Machine Type
        "VirtualBox" 				{ $MachineType="VM" }
        # Check for Xen
        "HVM domU" 					{ $MachineType="VM" }
        # Otherwise it is a physical Box
        default 					{ $MachineType="Physical" }
   	}               
	$mm = @{}
    $mm['Type'] = $MachineType 
	$mm['Manufacturer'] = $ComputerSystemInfo.Manufacturer
	$mm['Model'] = $ComputerSystemInfo.Model
	$t = $mm.Type
	$m = $mm.Manufacturer
	$md = $mm.Model
	$dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Machines]([ComputerName],[Type],[Manufacturer],[Model]) VALUES "
	$dbinsert = $dbinsert + "('" + $Computer + "','" + $t + "','" + $m + "','" + $md + "')"  
	$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $dbinsert, "master"))			
}
 
$GetClusterResources =
{
	param($computerName)
    $session = New-PSSession -computerName $computername -Authentication Kerberos #-credential $credential 
    $scriptBlock = 
    {
        import-module failoverclusters
        Get-ClusterResource
    }
    
    Invoke-Command -computerName $computername -scriptBlock $scriptBlock
    Remove-PSSession -computerName $computername
} 
#===========================functions and scriptblocks end=================================================




#======================Start Program============================================
$global:SERVERNAME = "CCLDEVSHRDDB1\DEVSQL2"
$ErrorActionPreference = "silentlycontinue"
$CLUSTERNAMES = "ccldceshrdcl1", "ccluatdtscl2", "ccluatdtscl4" 
$SAVESERVER = ""
$CONCURRENCY = 20

# COMMENTED FOR TESTING DO NO DELETE!!!

cls
"Process started " 
$d1 = Get-Date
$d1
" "
"Killing existing jobs . . ."
Get-Job | Remove-Job -Force
"Done."
" "





#Moved this to top of process
Write-Host "Start time two server tables: " (get-date)
#=======================Start server section=================================
# populating table SERVERS_LIVE_TODAY and Machines
Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, 'truncate table [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY]', "master")
Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, 'truncate table [Master_Application_List].[dbo].[Machines]', "master")
$listofservers = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_GetServers, "master"))

foreach ($k in $listofservers)
{
	if ($k.Machine -gt '')
	{
		$running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
	    if ($running.Count -le $CONCURRENCY) 
	    {
			
			Start-Job -ScriptBlock $CheckPing  -ArgumentList ($k.Machine, $global:SERVERNAME) 		| Out-Null
			Start-Job -ScriptBlock $GetMachineType -ArgumentList ($k.Machine, $global:SERVERNAME)   | Out-Null
		}
		else
	    { 
			$running | Wait-Job | out-null
		}	
	}
}	

(Get-Job | Receive-Job) | out-null

Write-Host "End time two server tables: " (get-date)
#=======================End of servers=================================

#Exit

#========================Start of sql server tables====================
$SqlServerList = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_GetSQLServers, "master"))

Write-Host "Start time five sql server tables: " (get-date)
# Cleaning destination tables
Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table Master_Application_List.[dbo].[Database Files]", "master")
Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[All Logins]", "master")
Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[All Users]", "master")
Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[Servers and Databases]", "master")
Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[Missing Backups]", "master")

"Killing existing jobs . . ."
Get-Job | Remove-Job -Force
"Done."
" "

$cnt = 0
foreach ($x in $SqlServerList)	# ----------Start Outer Server Loop---------------
{
    $SC = $x.SqlServer
    if ($SC -gt '')
    {#--start of current server---
	    $scurr = [char]34 + $SC	+ [char]34
	    $running = @(Get-Job  | Where-Object { $_.State -eq 'Running' })
	    if ($running.Count -le $CONCURRENCY) 
	    {
			Start-Job -ScriptBlock $Fill_DB_Files -ArgumentList ($scurr, $SQL_Get_Database_Files_Query, $global:SERVERNAME)  	| Out-Null
            Start-Job -ScriptBlock $Fill_All_Logins -ArgumentList ($scurr, $SQL_GetLogins, $global:SERVERNAME)					| Out-Null	
			Start-Job -ScriptBlock $Fill_All_Users -ArgumentList ($scurr, $SQL_GetUsers, $global:SERVERNAME) 					| Out-Null
			Start-Job -ScriptBlock $Fill_Server_And_DBs -ArgumentList ($scurr, $SQL_Get_DBSFromServer, $global:SERVERNAME)  	| Out-Null			
			Start-Job -ScriptBlock $Fill_Missing_Backups -ArgumentList ($scurr, $SQL_GetBackupInfo, $global:SERVERNAME) 		| Out-Null		
	    } 
	    else
	    {
		    $running | Wait-Job | Out-Null
	    }	
		
		$cnt++
    }#---end of current server---
} # ------------------------------------------------End Outer Server Loop---------------

(Get-Job | Receive-Job ) | out-null


#Set-content -path c:\temp\svr.txt $SAVESERVER
Write-Host "Processed " $cnt.ToString() "servers"
Write-Host "End time five sql server tables: " (get-date)
#==========================End of sql server tables====================



##### end of COMMENTED FOR TESTING




#==========================Start of misc steps (non jobs)===============
Write-Host "Start time misc steps " (get-date)
# Now we need to merge (insert/update) the entries in [Servers and Databases] with
# the ones in [Environments And Applications]
$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_GetMissingFrom_ServersAndDatabases, "master"))

# Fix #1: SQlVersion is obtained during db expansion, so we update back also onlineoffline
$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_FixVersionsAndOnlineOffline, "master"))
# Update from main storage table [Environments And Applications BACKUP] the expanded lines in [Environments And Applications]
$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_UpdateFrom_EnvironmentsAndApplicationsBACKUP, "master"))
#insert to Missing backups history
$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_InsertIntoBackupHistory, "master"))
#Not doing this now 
#Final insert from production lines in [Environments And Applications BACKUP]
#Invoke-Sqlcmd3 $SERVERNAME $SQL_Insert_Production_Values
#$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_Insert_Production_Values, "master"))
Write-Host "End time misc steps " (get-date)
#>
#==========================End of misc steps (non jobs)=================



#==========================Start of AG and clusters=========================
Write-Host "Start time AG and clusters " (get-date)
$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, 'truncate table Master_Application_List.[dbo].[AG_IPADDRESS_CHECK]', "master"))
$SERVERLIST = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_Serverlist_AG, "master"))
foreach ($k in $SERVERLIST)
{
	$svr = [char]34 + $k.Server + [char]34
	$j = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($svr, $SQL_LIST_AG_IPS, "master"))
    foreach ($r in $j)
    {
        $s = "INSERT INTO Master_Application_List.[dbo].[AG_IPADDRESS_CHECK]([dns_name],[port],[ip_address],[ip_subnet_mask],[state_desc],[Data_Center]) VALUES "
        $s = $s + "('" + $r.dns_name + "','" + ,$r.port +  "','" +,$r.ip_address + "','" + $r.ip_subnet_mask + "','" + $r.state_desc + "','" + $r.Data_Center + "')"
		$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $s, "master"))
    }
}

$clusterset = @{}
#truncate table first
$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table Master_Application_List.[dbo].[CLUSTERS]", "master"))

foreach ($h in $CLUSTERNAMES) # "ccldceshrdcl1", "ccluatdtscl2", "ccluatdtscl4" 
{
#   	$clusterset[$h] = GetClusterResources $h
	$clusterset[$h] = (Invoke-Command -ScriptBlock $GetClusterResources -ArgumentList ($h))
    foreach ($k in $clusterset[$h])
    {   
        if ($k.ToString().Contains(".") -and $k.ToString().Contains("_"))
        {
            $m = $k.ToString().Replace("_", "|")
            $s = $h + '|' + $m
            $v = $s.Split("|")
            $sql = "INSERT INTO Master_Application_List.[dbo].[CLUSTERS] ([ClusterMachine],[AG_Group],[IP_ADDRESS]) VALUES "
            $sql = $sql + "('" + $v[0] + "','" + $v[1]  + "','" + $v[2] + "')"
			$null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $sql, "master"))
        }
    }
}
Write-Host "End time AG and clusters " (get-date)
#==========================end of AG and clusters===========================

