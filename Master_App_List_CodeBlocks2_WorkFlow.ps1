﻿#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# version in version in \\CCLDEVSHRDDB1\e$\POWERSHELL (production)
# Created on:   9/13/2019 4:54 PM
# 9/18/2019: full test with workflow files
# Master_App_List_CodeBlocks_WorkFlow.ps1, Master_App_List_CodeBlocks2_WorkFlow.ps1, Master_App_List_version4_WorkFlow.ps1
# Created by:   
# Organization: 
# Filename:  Master_App_List_CodeBlocks2_WorkFlow.ps1
#changed 10/18/2019 $CheckPing
# added $GetServices
# changed 5/4/2020: if ($ret -eq $True)
#========================================================================

#===========================functions and scriptblocks=================================================     
$Fill_All_Sys_Configurations =
{
    param ($SC, $SQL_sys_configurations)
    . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1
    $SC2 = [char]34 + $SC + [char]34
    $ErrorActionPreference = "silentlycontinue"
    $l = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC2, $SQL_sys_configurations, "master"))
    foreach($y in $l)
    {
        if ($SC -gt '' -and $y.name -gt '')
        {
            $name = $y.name
            $value = $y.value        
            $insert = "INSERT INTO [Master_Application_List].[dbo].[Sys_Configurations] ([SQLSERVER],[name],[value]) VALUES "
            $insert = $insert + " ('" + $SC + "','" + $name  + "','" + $value + "')" 
            $ErrorActionPreference = "silentlycontinue"
            $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $insert, "master"))
        }
    }
}
    
$Fill_All_Logins =
{
    param ($SC, $SQL_GetLogins)
    . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1
    $SC2 = [char]34 + $SC + [char]34 
    $ErrorActionPreference = "silentlycontinue"
    $l = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC2, $SQL_GetLogins, "master"))
    foreach($y in $l)
    {
        if ($SC -gt '' -and $y.name -gt '')
        {
           $name = $y.name
           $dbname = $y.dbname
           $sysadmin = $y.sysadmin
           $isntgroup = $y.isntgroup
           $isntuser = $y.isntuser 
           $sid = $y.sid
#           $logininsert = "INSERT INTO [Master_Application_List].[dbo].[All Logins] ([SQLSERVER],[name],[dbname],[sysadmin],[isntgroup],[isntuser]) VALUES "
#           $logininsert = $logininsert + " ('" + $SC + "','" + $name + "','" + $dbname + "','" + $sysadmin + "','" + $isntgroup + "','" + $isntuser + "')" 
           $logininsert = "INSERT INTO [Master_Application_List].[dbo].[All Logins] ([SQLSERVER],[name],[dbname],[sysadmin],[isntgroup],[isntuser], [sid]) VALUES "
           $logininsert = $logininsert + " ('" + $SC + "','" + $name + "','" + $dbname + "','" + $sysadmin + "','" + $isntgroup + "','" + $isntuser + "'," + $sid + ")" 

           $ErrorActionPreference = "silentlycontinue"
           $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $logininsert, "master"))
        }
    }
}

$Fill_All_Users =
{
    param ($SC, $SQL_GetUsers)
    . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1	
	$SC2 = [char]34 + $SC + [char]34 
    $ErrorActionPreference = "silentlycontinue"
    $usersdb = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC2, $SQL_GetUsers, "master"))	
    foreach($uu in $usersdb)
    {
        if ($SC -gt '' -and $uu.UserName -gt '')
        {	
          $dbname = $uu.DBName
          $username = $uu.UserName
          $rolename = $uu.RoleName
          $SC2 = $SC.Replace('"', '') 
          $userinsert = "INSERT INTO [Master_Application_List].[dbo].[All Users] ([SQLSERVER],[DB Name],[User Name],[Role Name]) VALUES "
          $userinsert = $userinsert + " ('" + $SC + "','" + $dbname + "','" + $username + "','" + $rolename + "')"
          $ErrorActionPreference = "silentlycontinue"
          $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $userinsert, "master"))
        }
    }   
}

$Fill_DB_Files = 
{
    param ($SC, $SQL_Get_Database_Files_Query)
    . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1   
    $SC2 = [char]34 + $SC + [char]34
    $ErrorActionPreference = "silentlycontinue"
    $d = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC2, $SQL_Get_Database_Files_Query, "master"))	
    foreach($y in $d)
    {
        if ($SC -gt '' -and $y.DatabaseName -gt '')
        {
            $o = $y.DatabaseName
            $v = $y.LogicalFileName
            $h = $y.PhysicalFileName
            $g = $y.Type
            $z = $y.size
            $dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Database Files] ([SQLServer],[DatabaseName],[LogicalFileName],[PhysicalFileName],[Type],[size]) VALUES "
            $dbinsert = $dbinsert + "('" + $SC  + "','" + $o + "','" + $v +  "','" + $h + "','" + $g + "'," + $z + ")" 
            $ErrorActionPreference = "silentlycontinue"
            $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $dbinsert, "master"))
        }
    }
}

$Fill_Server_And_DBs = 
{
    param ($SC, $SQL_Get_DBSFromServer)
    . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1    
    $SC2 = [char]34 + $SC + [char]34
    $ErrorActionPreference = "silentlycontinue"    
    $svrdbs = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC2, $SQL_Get_DBSFromServer, "master"))	
    foreach ($y in $svrdbs)
    {
        $n = $y.name
        if ($n -gt '')
        {
          $o = $y.Online_Offline
          $v = $y.SqlVersion
          $SC2 = $SC.Replace('"', '') 
          $dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Servers and Databases] ([SQLServer],[Database_Name],[Online_Offline],[SqlVersion]) VALUES"
          $dbinsert = $dbinsert + "('" + $SC + "','" + $n + "','" + $o + "','" + $v + "')" 
          # needed for servers with no access
          $ErrorActionPreference = "silentlycontinue"
          $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $dbinsert, "master"))
        }
    }	
}

$Fill_Missing_Backups = 
{
    param ($SC, $SQL_GetBackupInfo)
    . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1	
    
    $SC2 = [char]34 + $SC + [char]34
    $ErrorActionPreference = "silentlycontinue"
    $msbkp = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC2, $SQL_GetBackupInfo, "master"))
    foreach ($y in $msbkp)
    {
        $db = $y.db
        if ($db -gt '')
        {
          $dt = $y.bkdate
          $s = "INSERT INTO [Master_Application_List].[dbo].[Missing Backups]([SqlServer],[DBname],[BKDate]) VALUES ('"
          $s = $s + $SC + "','" + $db + "','" + $dt + "')"
          $ErrorActionPreference = "silentlycontinue"
          $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $s, "master"))
        }
    }	
}

#changed 10/18/2019
#using Test-Connection -ComputerName $server -Count 1 -ErrorAction SilentlyContinue -Quiet
$CheckPing = 
{
    param ($server)
    . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1	#ExecuteSQL imported here
    $ret = (Test-Connection -ComputerName $server -Count 1 -ErrorAction SilentlyContinue -Quiet) 

    # if ($ret -eq $True)
    if ($ret.ToString() -eq 'True')
    {
        $s = "INSERT INTO [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY] (Machine) VALUES ('" + $server + "')"		
    }
    else
    {
        $s = "INSERT INTO [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY] (Machine, Status) VALUES ('" + $server+ "', 'DEAD TODAY')"
    }
    $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $s, "master"))	
}

$GetMachineType =
{
    param($Computer)
    . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1	#$ExecuteSQL imported here	
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
    $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $dbinsert, "master"))			
} 

#New 11/12/2019
$GetServices =
{
    param($Computer)
    . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1	#$ExecuteSQL imported here	
    $ErrorActionPreference = "silentlycontinue"
    # $Credential = [System.Management.Automation.PSCredential]::Empty
    # # Check to see if $Computer resolves DNS lookup successfuly.
    # $null = [System.Net.DNS]::GetHostEntry($Computer)
    # $ComputerSystemInfo = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $Computer -ErrorAction silentlycontinue -Credential $Credential           
    $r = (Get-Service -ComputerName $Computer)
    foreach ($k in $r)
    {
        if ($k.Name -gt '')
        {
            $dbinsert = "INSERT INTO [Master_Application_List].[dbo].[ALL_SERVICES]([Computer],[servicename],[displayname],[status]) VALUES "
            $dbinsert = $dbinsert + "('" + $Computer + "','" + $k.Name + "','" + $k.DisplayName + "','" + $k.Status + "')"  
            $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $dbinsert, "master"))			
        }
    }
} 
#===========================functions and scriptblocks end=================================================

