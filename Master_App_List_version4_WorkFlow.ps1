<#
Master_app_List_version4_WorkFlow.ps1
#version in \\CCLDEVSHRDDB1\e$\POWERSHELL
made from Master_app_List_version4.ps1
Uses Master_app_List_CodeBlocks_WorkFlow.ps1 and Master_app_List_CodeBlocks2_WorkFlow.ps1
Created: 9/13/2019 
Last updated:
9/16/2019: good test with full population of the two tables
9/13/2019: Inital version only testing GetMachineType and CheckPing
#>


workflow Run-Workflow 
{
      InlineScript #1
      {
        Set-Location e:\POWERSHELL
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1  #ExecuteSQL, Invoke-SQLcmd3
        . e:\POWERSHELL\Master_App_List_CodeBlocks2_WorkFlow.ps1 #CheckPing, GetMachineType
        
        #======================Start Program============================================
#        $SERVERNAME = "CCLDEVSHRDDB1\DEVSQL2" comes from import from Master_App_List_CodeBlocks_WorkFlow.ps1
        $ErrorActionPreference = "silentlycontinue"
        cls
        "Process started " 
        $d1 = Get-Date
        $d1
        " "
        $m =  "Start time two server tables: " + (get-date).toString()
        $m        
     } #end of inlinescript 1
    
    # populating table SERVERS_LIVE_TODAY and Machines
    InlineScript #2
    {
        Set-Location e:\POWERSHELL
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1
        Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, 'truncate table [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY_XXX]', "master")
        Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($SERVERNAME, 'truncate table [Master_Application_List].[dbo].[Machines_XXX]', "master")
	}
    
    # Yes, you can return stuff from InlineScript
    $listofservers = InlineScript 
    {
        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1      
        $serverlist = (Invoke-Command -ScriptBlock $ExecuteSQL  -ArgumentList ($SERVERNAME, $SQL_GetServers, 'master') 	)
        return $serverlist
	}
    
    foreach –parallel ($k in $listofservers)
    {	
        sequence
        {    
            InlineScript
            { 
                Set-Location e:\POWERSHELL
                . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1   
                . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1
                . e:\POWERSHELL\Master_App_List_CodeBlocks2_WorkFlow.ps1
                Invoke-Command -ScriptBlock $CheckPing  -ArgumentList ($using:k.Machine) 		
                Invoke-Command -ScriptBlock $GetMachineType -ArgumentList ($using:k.Machine) 
			}                
	    } #end of sequence           
                
	}  #end of foreach -parallel           

    InlineScript #3
    {
        Set-Location e:\POWERSHELL
#        . e:\POWERSHELL\Master_App_List_SQL_WorkFlow.ps1
#        . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1  
        
        $m = "End time two server tables: " + (get-date).ToString()
        $m
    } #end of inlinescript 3
}   #end of workflow

Run-Workflow