#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   9/13/2019 4:54 PM
# Created by:   
# Organization: 
# Filename:  Master_App_List_CodeBlocks2_WorkFlow.ps1	   
#========================================================================

#===========================functions and scriptblocks=================================================    
$CheckPing = 
{
          param ($server)
          . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1	#ExecuteSQL
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
            $s = "INSERT INTO [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY_XXX] (Machine) VALUES ('" + $server + "')"		
          }
          else
          {
            $s = "INSERT INTO [Master_Application_List].[dbo].[SERVERS_LIVE_TODAY_XXX] (Machine, Status) VALUES ('" + $server+ "', 'DEAD TODAY')"
          }
          $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $s, "master"))	
}

$GetMachineType =
{
          param($Computer)
          . e:\POWERSHELL\Master_App_List_CodeBlocks_WorkFlow.ps1		
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
          $dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Machines_XXX]([ComputerName],[Type],[Manufacturer],[Model]) VALUES "
          $dbinsert = $dbinsert + "('" + $Computer + "','" + $t + "','" + $m + "','" + $md + "')"  
          $null = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($global:SERVERNAME, $dbinsert, "master"))			
} 
#===========================functions and scriptblocks end=================================================

