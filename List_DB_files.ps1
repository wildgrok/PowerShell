<#
List_DB_Files.ps1
Created: 11/19/2018
Last updated:
1/31/2019: fixed insertion part!
1/30/2019: working on jobs fixes

Will create report of all database files from all servers from table with servers

#>

#===========================functions start=================================================
#function Invoke-Sqlcmd3 ($ServerInstance,$Query, $Database)
function Invoke-Sqlcmd3 ($ServerInstance,$Query)
<#
	Chad Millers Invoke-Sqlcmd3
#>
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
#===========================functions end=================================================

#============================sql start====================================================
$SQL_GetSQLServers = 'select SqlServer from [Master_Application_List].[dbo].[VW_SQLSERVERS] order by SqlServer'
$SQL_Get_Database_Files_Query = 
@"
SELECT @@SERVERNAME AS SQLSERVER, DB_NAME(database_id) AS DatabaseName, name AS LogicalFileName, 
physical_name AS PhysicalFileName, 
case file_id 
	when 2 then 'Log'
	when 1 then 'Data'
	else 'Other' 
end as 'Type'
FROM sys.master_files
"@
#===========================sql end=================================================


#======================Start Program============================================
$SERVERNAME = "CCLUATSQL1\UATSQL3"
$ErrorActionPreference = "silentlycontinue"
$SqlServerList = (Invoke-Sqlcmd3 $SERVERNAME $SQL_GetSQLServers)
$d = @{}
# Cleaning destination table
$null = (Invoke-Sqlcmd3 $SERVERNAME "truncate table Master_Application_List.[dbo].[Database Files_XXX]")


#$SqlServerList = "ZZSQL3"
$cnt = 0
foreach ($x in $SqlServerList)	# ----------Start Outer Server Loop---------------
{
	$scurr = [char]34 + $x['SqlServer']	+ [char]34
	#Write-Host "Processing server " $scurr " for database files start"
    # ----------Start Loop----------------------------------------
	$running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
	#Write-Host "running count:" $running.Count.ToString()
	if ($running.Count -le 8) 
	{
		$null = Start-Job -ScriptBlock $ExecuteSQL -ArgumentList ($scurr, $SQL_Get_Database_Files_Query, "master") 
	} 
	else
	{
		$running | Wait-Job
	}	
	$d = (Get-Job | Receive-Job) 
	foreach($y in $d)
	{
		$s = $y.SQLSERVER
		if ($y.SQLSERVER -gt '')
		{
			$o = $y.DatabaseName
			$v = $y.LogicalFileName
			$h = $y.PhysicalFileName
			$g = $y.Type
			$dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Database Files_XXX] ([SQLServer],[DatabaseName],[LogicalFileName],[PhysicalFileName],[Type]) VALUES "
			$dbinsert = $dbinsert + "('" + $s  + "','" + $o + "','" + $v +  "','" + $h + "','" + $g + "')" 
			# needed for servers with no access
			$ErrorActionPreference = "silentlycontinue"
			$null = (Invoke-Sqlcmd3 $SERVERNAME $dbinsert)
		}

	}
	#$i = 0
	#foreach($m in $r)
	#{
	#cols are
	#$m.RunspaceId 
	#$m.SQLSERVER 
	#$m.DatabaseName    
	#$m.LogicalFileName 
	#$m.PhysicalFileName
	#$m.Type            
		##$k = $m[$i].RunspaceId  +    ':' + $m[$i].SQLSERVER    +    ':' + $m[$i].DatabaseName   + ':' 	+ $m[$i].LogicalFileName + ':' 	+ $m[$i].PhysicalFileName + ':' + $m[$i].Type
		#foreach($y in $m)
		#{
		##$y = $m.RunspaceId   # + ':' + $m.SQLSERVER    +    ':' + $m.DatabaseName   + ':' 	+ $m.LogicalFileName + ':' 	+ $m.PhysicalFileName + ':' + $m.Type

		#$formatOut = @()
		#for ($i=0; $i -le $m[$i].Length; $i++)
		#{
		#	$formatOut = $formatOut + ($y[$i].ItemArray -join ",")
		#}
		#Add-Content -Path C:\Users\jorgebe\Documents\powershell\List_DB_files.ps1.txt -Stream $formatOut -
		#$i = $i + 1
		#}
	#}

	#foreach ($m in $r)
	#{
	##$k = $m['RunspaceId']   +    ':' + $m['SQLSERVER']    +    ':' + $m['DatabaseName']    + ':' 	+ $m['LogicalFileName'] + ':' 	+ $m['PhysicalFileName'] + ':' + $m['Type'] 
	#$formatOut = $formatOut + ($m.ItemArray -join ",")
	#Add-Content -Path C:\Users\jorgebe\Documents\powershell\List_DB_files.ps1.txt $formatOut
	#}
	#Write-Output $m
	$cnt++
	if ($cnt -gt 10)
	{
		break;
	}
	#write-output $d["CCLDEVDTSDB1"].value
#	#Get comp info for current server
#	$dbfilelines = (Invoke-Sqlcmd3 $scurr $SQL_Get_Database_Files_Query)
#    #these are the columns
#    #    [DatabaseName]
#    #    [LogicalFileName]
#    #    [PhysicalFileName]
#    #    [Type])
#	foreach ($y in $dbfilelines)
#	{
#		$o = $y['DatabaseName']
#		$v = $y['LogicalFileName']
#        $h = $y['PhysicalFileName']
#        $g = $y['Type']
#        $dbinsert = "INSERT INTO [Master_Application_List].[dbo].[Database Files_XXX] ([SQLServer],[DatabaseName],[LogicalFileName],[PhysicalFileName],[Type]) VALUES "
#		$dbinsert = $dbinsert + "('" + $scurr  + "','" + $o + "','" + $v +  "','" + $h + "','" + $g + "')" 
##        $dbinsert
#		# needed for servers with no access
#		$ErrorActionPreference = "silentlycontinue"
#		Invoke-Sqlcmd3 $SERVERNAME $dbinsert
#	}											
	# ----------End Loop------------------------------------------- 
    #Write-Host "Processing server " $scurr " for database files end"
}# ------------------------------------------------End Outer Server Loop---------------
#========================End of Database Files====================


#Write-output "========="
#$dict
#Write-output "========="