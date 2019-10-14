#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   10/9/2019 5:22 PM
# Created by:   
# Organization: 
# Filename:     
#========================================================================
#https://stackoverflow.com/questions/26810722/powershell-workflow-and-parallel-not-giving-output

Workflow Test-Parallel
{
	$ServerList = @("Server1","Server2","Server3","Server4","Server5","Server6","Server7","Server8","Server9","Server10")
	ForEach -Parallel -ThrottleLimit $ServerList.Count ( $Server in $ServerList ) 
	{
		Write-Verbose "Starting $Server"
		$databases = InlineScript{
			@("db1","db2","db3","db4","db5","db6","db7","db8","db9","db10","db11","db12")
		}
		ForEach -Parallel -ThrottleLimit 10 ( $database in $databases ) 
		{
			InlineScript{
				$database = $using:database
				$Server = $using:Server
				Write-Verbose "Starting $database on $Server"
				Start-Sleep -seconds 5
			}
		}
	}
}

Test-Parallel -Verbose