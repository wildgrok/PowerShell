<#
Master_app_List_version4_WorkFlow.ps1
#version in \\CCLDEVSHRDDB1\e$\POWERSHELL
made from Master_app_List_version4.ps1
Uses Master_app_List_CodeBlocks_WorkFlow.ps1 and Master_app_List_CodeBlocks2_WorkFlow.ps1
Created: 9/13/2019 
Last updated:
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
       
    
    # populating table SERVERS_LIVE_TODAY and Machines
    InlineScript #2
    {
        Set-Location e:\POWERSHELL
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1        # to import $SQL_Truncate_Server_Tables  
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1 # to import ExecuteSQL        
        $m =  "Start time two server tables: " + (get-date).toString()
        $m                 
        # clear SERVERS_LIVE_TODAY and Machines tables
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME,$SQL_Truncate_Server_Tables))
	}       # end of inlinescript 2
    
    # Yes, you can return stuff from InlineScript
    $listofservers = InlineScript #3
    {
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1      
        $serverlist = (Invoke-Command -ScriptBlock $ExecuteSQL  -ArgumentList ($SERVERNAME, $SQL_GetServers, 'master') 	)
        return $serverlist
	}       # end of inlinescript 3
    
    # this section processes the servers (not sql servers)
    foreach –parallel ($k in $listofservers)
    {	
        sequence
        {    
            InlineScript        # first set of actions to be completed in parallel: machine related                  
            { 
                Set-Location e:\POWERSHELL
                . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
                . e:\POWERSHELL\Master_App_List_CodeBlocks2_WorkFlow.ps1
                $null = (Invoke-Command -ScriptBlock $CheckPing  -ArgumentList ($using:k.Machine)) 		
                $null = (Invoke-Command -ScriptBlock $GetMachineType -ArgumentList ($using:k.Machine)) 
			}                
	    }   #end of sequence                           
	}       #end of foreach -parallel 
    
    InlineScript # just of display
    {
        $m = "End time two server tables: " + (get-date).ToString() + " Starting now 6 sql server tables"
        $m
	}
    
    #Now we start a new parallel process, this time for the SQL servers
    #Preparing conditions, getting list of sql servers
    $SqlServerList = InlineScript #4
    {
        Set-Location e:\POWERSHELL
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1   #imports ExecuteSQL and $SERVERNAME
        #. e:\POWERSHELL\Master_App_List_CodeBlocks2_WorkFlow.ps1 #not needed, only using ExecuteSQL 
                
        # Cleaning destination tables
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME,$SQL_Truncate_SQL_Tables))
        #Needed
        $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $SQL_Reload_EnvironmentsAndApplications , "master") )#uses [Environments And Applications]
        #Get list of sql servers, return it
        $SqlServerList = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, $SQL_GetSQLServers, "master"))
        return $SqlServerList        
    }       #end of inlinescript 4
    
    #Now that we have the list of sql servers we start a new parallel process
    foreach –parallel ($k in $SqlServerList)
    {	
        sequence
        {    
            InlineScript        # second set of actions to be completed in parallel: sqlserver related                  
            { 
                Set-Location e:\POWERSHELL
                . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
                #. e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1 no need to call, included in next line import
                . e:\POWERSHELL\Master_App_List_CodeBlocks2_WorkFlow.ps1
                $null = (Invoke-Command -ScriptBlock $Fill_All_Sys_Configurations -ArgumentList ($using:k.SqlServer, $SQL_sys_configurations) )
                $null = (Invoke-Command -ScriptBlock $Fill_DB_Files -ArgumentList ($using:k.SqlServer, $SQL_Get_Database_Files_Query) ) 	        
                $null = (Invoke-Command -ScriptBlock $Fill_All_Logins -ArgumentList ($using:k.SqlServer, $SQL_GetLogins) )
                $null = (Invoke-Command -ScriptBlock $Fill_All_Users -ArgumentList ($using:k.SqlServer, $SQL_GetUsers) )
                $null = (Invoke-Command -ScriptBlock $Fill_Server_And_DBs -ArgumentList ($using:k.SqlServer, $SQL_Get_DBSFromServer) )		
                $null = (Invoke-Command -ScriptBlock $Fill_Missing_Backups -ArgumentList ($using:k.SqlServer, $SQL_GetBackupInfo) )
			}                
	    }   #end of sequence                           
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
        # Now we need to merge (insert/update) the entries in [Servers and Databases] with
        # the ones in [Environments And Applications]
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