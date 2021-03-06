﻿<#
Master_app_List_version4_WorkFlow.ps1
#version in \\CCLDEVSHRDDB1\e$\POWERSHELL
made from Master_app_List_version4.ps1
Uses Master_app_List_CodeBlocks_WorkFlow.ps1 and Master_app_List_CodeBlocks2_WorkFlow.ps1
Created: 9/13/2019 
Last updated:
#4/28/2020: changed foreach –parallel -ThrottleLimit 500 (chekcing issues with servers_live_today)
#1/17/2020: many changes related to servers_live_today population
9/24/2019: commented the sequence statements, also tested inlinescript for each line, did not work, much longer exec time
9/18/2019: full test with workflow files
Master_App_List_CodeBlocks_WorkFlow.ps1, Master_App_List_CodeBlocks2_WorkFlow.ps1, Master_App_List_version4_WorkFlow.ps1
9/16/2019: good test with full population of the two tables
9/13/2019: Inital version only testing GetMachineType and CheckPing
#>


workflow Run-Workflow 
{
    InlineScript #1
    {
        Set-Location e:\POWERSHELL
        $ErrorActionPreference = "silentlycontinue"
        cls
        "Process started " 
        $d1 = Get-Date
        $d1
        " "           
    }       # end of inlinescript 1
       
    
    # populating table SERVERS_LIVE_TODAY
    InlineScript #2
    {
        Set-Location e:\POWERSHELL
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1        # to import $SQL_Truncate_Server_Tables  
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1 # to import ExecuteSQL        
        $m =  "Start time three server tables: " + (get-date).toString()
        $m                 
        # clear SERVERS_LIVE_TODAY, Machines, ALL_SERVICES tables
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME,$SQL_Truncate_Server_Tables))
	}       # end of inlinescript 2
    
    # Yes, you can return stuff from InlineScript
    $listofservers = InlineScript #3
    {
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1 
        # $SQL_GetServers = 'select Machine from [Master_Application_List].[dbo].[VW_SERVERS] order by Machine'     
        $serverlist = (Invoke-Command -ScriptBlock $ExecuteSQL  -ArgumentList ($SERVERNAME, $SQL_GetServers, 'master') 	)
        return $serverlist
	}       # end of inlinescript 3
    
    # this section processes the servers (not sql servers)
    #  Changed: original list conatins all servers , now from this list we get the list after ping check 
    # table servers-live_today is populated after this step
    foreach –parallel -ThrottleLimit 500 ($k in $listofservers)
    {	  
        InlineScript        # first set of actions to be completed in parallel: ping related                  
        { 
            Set-Location e:\POWERSHELL
            . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
            . e:\POWERSHELL\Master_App_List_CodeBlocks2_WorkFlow.ps1
             $null = (Invoke-Command -ScriptBlock $CheckPing  -ArgumentList ($using:k.Machine)) 
		}                                          
    }       #end of foreach -parallel 

    # added 4/28/2020
    Start-Sleep -s 15

    $listofservers_live = InlineScript 
    {
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1 
        #  $SQL_GetServers_Live brings data (Machine) from servers_live_today      
        $serverlist_live = (Invoke-Command -ScriptBlock $ExecuteSQL  -ArgumentList ($SERVERNAME, $SQL_GetServers_Live, 'master') 	)
        return $serverlist_live
	}  

    foreach –parallel -ThrottleLimit 500 ($k in $listofservers_live)
    {	   
        InlineScript        # second set of actions to be completed in parallel: machine related                  
        { 
            Set-Location e:\POWERSHELL
            . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
            . e:\POWERSHELL\Master_App_List_CodeBlocks2_WorkFlow.ps1
            $null = (Invoke-Command -ScriptBlock $GetMachineType -ArgumentList ($using:k.Machine)) 
            $null = (Invoke-Command -ScriptBlock $GetServices -ArgumentList ($using:k.Machine)) 
		}                                         
	}      

    InlineScript # just of display
    {
        $m = "End time three server tables: " + (get-date).ToString()
        $m
        "Starting now 6 sql server tables"
	}
    
    #Now we start a new parallel process, this time for the SQL servers
    #Preparing conditions, getting list of sql servers
    $SqlServerList = InlineScript #4
    {
        Set-Location e:\POWERSHELL
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1   #imports ExecuteSQL and $SERVERNAME
        # Cleaning destination tables
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME,$SQL_Truncate_SQL_Tables))
        #Needed
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $SQL_Reload_EnvironmentsAndApplications , "master") )#uses [Environments And Applications]
        #Get list of sql servers, return it 
        $SqlServerList = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $SQL_GetSQLServers_Live, "master"))
        return $SqlServerList        
    }       #end of inlinescript 4
    
    #Now that we have the list of sql servers we start a new parallel process
    foreach –parallel -ThrottleLimit 50 ($k in $SqlServerList)
    {	
        InlineScript
        {
            Set-Location e:\POWERSHELL
            . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
            . e:\POWERSHELL\Master_App_List_CodeBlocks2_WorkFlow.ps1
            $null = (Invoke-Command -ScriptBlock $Fill_All_Sys_Configurations -ArgumentList ($using:k.SqlServer, $SQL_sys_configurations) )
            $null = (Invoke-Command -ScriptBlock $Fill_DB_Files -ArgumentList ($using:k.SqlServer, $SQL_Get_Database_Files_Query) ) 	        
            $null = (Invoke-Command -ScriptBlock $Fill_All_Logins -ArgumentList ($using:k.SqlServer, $SQL_GetLogins) )
            $null = (Invoke-Command -ScriptBlock $Fill_All_Users -ArgumentList ($using:k.SqlServer, $SQL_GetUsers) )
            $null = (Invoke-Command -ScriptBlock $Fill_Server_And_DBs -ArgumentList ($using:k.SqlServer, $SQL_Get_DBSFromServer) )		            
            $null = (Invoke-Command -ScriptBlock $Fill_Missing_Backups -ArgumentList ($using:k.SqlServer, $SQL_GetBackupInfo) )			                
		}
	}       #end of foreach -parallel 
    
    InlineScript #5
    {
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1        # imports sql 
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1 # imports ExecuteSQL
        $m = "End time six server tables: " + (get-date).ToString()
        $m       
        #==========================Start of final misc steps ===============
        $m = "Start time misc steps " + (get-date).ToString()
        $m
        # Merge (insert/update) the entries in [Servers and Databases] withthe ones in [Environments And Applications]
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $SQL_GetMissingFrom_ServersAndDatabases, "master"))
        # SQLVersion is obtained during db expansion, so we update back also onlineoffline
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $SQL_FixVersionsAndOnlineOffline, "master"))
        # Update from main storage table [Environments And Applications BACKUP] the expanded lines in [Environments And Applications]
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $SQL_UpdateFrom_EnvironmentsAndApplicationsBACKUP, "master"))
        #insert to Missing backups history
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $SQL_InsertIntoBackupHistory, "master"))
        $m =  "End time misc steps and program " + (get-date).ToString()
        $m
        #==========================End of misc steps ========================     
    }
    
    
}   #end of workflow

Run-Workflow