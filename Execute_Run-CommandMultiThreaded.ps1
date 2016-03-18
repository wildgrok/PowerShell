# Execute_Run-CommandMultiThreaded.ps1
#Last updated
#7/1/2015:  modified to use new CONFIG.ps1 file

# Calls Run-CommandMultiThreaded.ps1
# Expects parameters DBLIST and MaxThreads (set in CONFIG.ps1 file)
# If MaxThreads is 0 it will use the total number of lines enabled in the text file

# Import globals
Set-Location 'D:\Users\jorgebe\Documents\powershell'
#. .\CONFIG.ps1

$global:SQLSTORAGESTRING 	= ''
$global:LOGSQLFILE 			= 'SQLLOG.SQL'
$global:ACTIONSFILE 		= 'ACTIONS.DAT'
$global:DBLIST 				= 'DBLIST_ACTIONS_LATEST.CSV'
$global:MAXTHREADS 			= 0


# used for automatic thread option: 
function CountEnabledLines($file)
<#
	Returns count of lines ending in ,Y
#>
{
	$cnt = 0
	$z = Get-Content $file
	foreach ($x in $z)
	{
		$m = $x.TrimEnd()
		if ($m[-2] + $m[-1] -eq ',Y')
		{
			 $cnt = $cnt + 1
		}
	}		
	return $cnt
}

# If $global:MAXTHREADS is 0 we want to use the max number of threads, one per enabled line
if ($global:MAXTHREADS -eq 0){ $global:MAXTHREADS = CountEnabledLines ($global:DBLIST)}
Write-Host "Using " $global:MAXTHREADS " threads"

# Run the program
gc $global:DBLIST | .\Run-CommandMultiThreaded.ps1 -Command .\ItemActions.ps1 -MaxThreads $global:MAXTHREADS
#gc $global:DBLIST | .\Run-CommandMultiThreaded.ps1 -Command .\ItemActions_WORKFLOW.ps1 -MaxThreads $global:MAXTHREADS
#gc $global:DBLIST | .\Run-CommandMultiThreaded.ps1 -Command .\ItemActions_DEMO.ps1 -MaxThreads $global:MAXTHREADS

#$args
