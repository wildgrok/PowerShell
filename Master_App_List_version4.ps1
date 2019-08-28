<#
Master_app_List_version4.ps1
#version in \\CCLDEVSHRDDB1\e$\POWERSHELL
made from List_DB_Files.ps1
Created: 4/3/2019 out of Master_app_List_version3.ps1
Last updated:
8/28/2019: converted to fake workflow, changed all write-host
8/20/2019: added size column to table [Database Files] and related population
6/7/2019: added missing call to $SQL_Reload_EnvironmentsAndApplications
5/29/2019: cluster check moved to single file ClusterCheck3.ps1
#>


workflow Run-Workflow 
{
  InlineScript 
  {
    Set-Location e:\POWERSHELL
    # Imports
    . e:\POWERSHELL\Master_App_List_SQL.ps1
    <#
        Contents of Master_App_List_SQL.ps1

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

    . e:\POWERSHELL\Master_App_List_CodeBlocks.ps1

    #===========================functions and scriptblocks=================================================

    $Fill_All_Logins =
    {
      param ($SC, $SQL_GetLogins, $global:SERVERNAME)
	
      # Imports
      . e:\POWERSHELL\Master_App_List_CodeBlocks.ps1
	
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
      param ($SC, $SQL_GetUsers, $global:SERVERNAME)
      # Imports
      . e:\POWERSHELL\Master_App_List_CodeBlocks.ps1	
	
      $usersdb = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_GetUsers, "master"))	
      foreach($uu in $usersdb)
      {
        if ($SC -gt '' -and $uu.UserName -gt '')
        {	
          $dbname = $uu.DBName
          $username = $uu.UserName
          $rolename = $uu.RoleName
          $SC2 = $SC.Replace('"', '') 
          $userinsert = "INSERT INTO [Master_Application_List].[dbo].[All Users] ([SQLSERVER],[DB Name],[User Name],[Role Name]) VALUES "
          $userinsert = $userinsert + " ('" + $SC2 + "','" + $dbname + "','" + $username + "','" + $rolename + "')"
          $ErrorActionPreference = "silentlycontinue"
          $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $userinsert, "master"))
        }
      }   
    }

    $Fill_DB_Files = 
    {

      param ($SC, $SQL_Get_Database_Files_Query, $global:SERVERNAME)
      # Imports
      . e:\POWERSHELL\Master_App_List_CodeBlocks.ps1		
      $d = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_Get_Database_Files_Query, "master"))	
      foreach($y in $d)
      {
        if ($SC -gt '' -and $y.DatabaseName -gt '')
        {
          $o = $y.DatabaseName
          $v = $y.LogicalFileName
          $h = $y.PhysicalFileName
          $g = $y.Type
          $z = $y.size
          $SC2 = $SC.Replace('"', '') 
          $dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Database Files] ([SQLServer],[DatabaseName],[LogicalFileName],[PhysicalFileName],[Type],[size]) VALUES "
          $dbinsert = $dbinsert + "('" + $SC2  + "','" + $o + "','" + $v +  "','" + $h + "','" + $g + "'," + $z + ")" 
          $ErrorActionPreference = "silentlycontinue"
          $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $dbinsert, "master"))
        }
      }
    }

    $Fill_Server_And_DBs = 
    {
      param ($SC, $SQL_Get_DBSFromServer, $global:SERVERNAME)
      # Imports
      . e:\POWERSHELL\Master_App_List_CodeBlocks.ps1	
      $svrdbs = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_Get_DBSFromServer, "master"))	
      foreach ($y in $svrdbs)
      {
        $n = $y.name
        if ($n -gt '')
        {
          $o = $y.Online_Offline
          $v = $y.SqlVersion
          $SC2 = $SC.Replace('"', '') 
          $dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Servers and Databases] ([SQLServer],[Database_Name],[Online_Offline],[SqlVersion]) VALUES"
          $dbinsert = $dbinsert + "('" + $SC2 + "','" + $n + "','" + $o + "','" + $v + "')" 
          # needed for servers with no access
          $ErrorActionPreference = "silentlycontinue"
          $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $dbinsert, "master"))
        }
      }	
    }

    $Fill_Missing_Backups = 
    {
      param ($SC, $SQL_GetBackupInfo, $global:SERVERNAME)
      # Imports
      . e:\POWERSHELL\Master_App_List_CodeBlocks.ps1			
      $msbkp = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SC, $SQL_GetBackupInfo, "master"))
      foreach ($y in $msbkp)
      {
        $db = $y.db
        if ($db -gt '')
        {
          $dt = $y.bkdate
          #		$svr = [char]39 + [char]34 + $scurr + [char]34 + [char]39
          $SC2 = $SC.Replace('"', '') 
          $s = "INSERT INTO [Master_Application_List].[dbo].[Missing Backups]([SqlServer],[DBname],[BKDate]) VALUES ('"
          $s = $s + $SC2 + "','" + $db + "','" + $dt + "')"
          $ErrorActionPreference = "silentlycontinue"
          $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $s, "master"))
        }
      }	
    }

    $CheckPing = 
    {
      param ($server, $global:SERVERNAME)
      # Imports
      . e:\POWERSHELL\Master_App_List_CodeBlocks.ps1	
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
      param($Computer, $global:SERVERNAME)
      # Imports
      . e:\POWERSHELL\Master_App_List_CodeBlocks.ps1		
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
 
    #===========================functions and scriptblocks end=================================================




    #======================Start Program============================================
    $global:SERVERNAME = "CCLDEVSHRDDB1\DEVSQL2"
    $ErrorActionPreference = "silentlycontinue"
    #5/17/2019 added cluster CCLUATSBLCL1
    $CLUSTERNAMES = "ccldceshrdcl1", "ccluatdtscl2", "ccluatdtscl4", "CCLUATSBLCL1" 
    $SAVESERVER = ""
    $CONCURRENCY = 20


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
    $m =  "Start time two server tables: " + (get-date).toString()
    $m
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

    $m = "End time two server tables: " + (get-date).ToString()
    $m
    #=======================End of servers=================================

   


    #========================Start of sql server tables====================

    $m = "Start time five sql server tables: " + (get-date).ToString()
    $m
    # Cleaning destination tables
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[Database Files]", "master")
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[All Logins]", "master")
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[All Users]", "master")
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[Servers and Databases]", "master")
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[Missing Backups]", "master")
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, "truncate table [Master_Application_List].[dbo].[Environments And Applications]" , "master")

    #6/7/2019
    # this is not part of servers or databases feed, not in job
    Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_Reload_EnvironmentsAndApplications , "master")

    "Killing existing jobs . . ."
    Get-Job | Remove-Job -Force
    "Done."
    " "

    $SqlServerList = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $SQL_GetSQLServers, "master"))
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
    $m =  "Processed " + $cnt.ToString() + " servers"
    $m
    $m = "End time five sql server tables: " + (get-date).ToString()
    $m
    #==========================End of sql server tables====================


    #==========================Start of misc steps (non jobs)===============
    $m = "Start time misc steps " + (get-date).ToString()
    $m
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
    $m =  "End time misc steps " + (get-date).ToString()
    $m
    #>
    #==========================End of misc steps (non jobs)=================


  } #end of big inlinescript
}   #end of workflow

Run-Workflow