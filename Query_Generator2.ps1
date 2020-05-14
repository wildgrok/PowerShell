
#﻿Query_Generator2.ps1
#version in 
#C:\TEMP
#Last Modified:
#4/29/2020: added [ and ] to table and column names
#4/20/2020: using it for TableGames in xxdevsql3


#-------globals-----------------------------
#$path = 'C:\TEMP\genesis\change_tracking_genesis\deployment'
#$path = 'C:\TEMP\genesis\JackpotBlitz\Data Strategy Data Transfer Service\DEPLOYMENT'
$path = 'C:\TEMP\deployment'

Set-Location $path
# $CURRENT_DATABASE = "TableGames"
# $CURRENT_SERVER   = 'XXDEVSQL3'
#$CURRENT_DATABASE = "Genesis_Breeze"
#$WEBMETHODS_DATABASE = "WM_AUDIT"
#$CURRENT_SERVER   = 'XXDEVSQL3'
#$CURRENT_DATABASE = "TableGames"
#$CURRENT_SERVER   = 'XXDEVSQL3'
#$CURRENT_DATABASE = "Genesis_Breeze"
#$WEBMETHODS_DATABASE = "WM_AUDIT"
#$CURRENT_SERVER   = 'XXDEVSQL3'

$CURRENT_DATABASE = "DebitCard_Data"
$CURRENT_SERVER   = 'STSQL6.SHIPTECH.CARNIVAL.COM,3655'
#$CURRENT_DATABASE = "Genesis_Breeze"
#$WEBMETHODS_DATABASE = "WM_AUDIT"
#$CURRENT_SERVER   = 'XXDEVSQL3'

# $CURRENT_DATABASE = "Tablegames"
# $CURRENT_SERVER   = '10.111.242.35,1433'
# $USER = 'Jbesada'
# $PASSWORD = 'Carnival99!'



$CRLF = [char]13 + [char]10
$s = "select  ('[' + s.name + '].[' + t.name + ']') as 'table', '[' +  a.name + ']' as 'column' from " + $CURRENT_DATABASE + ".sys.columns a "
$s = $s + "join " + $CURRENT_DATABASE +  ".sys.tables t on 	a.object_id = t.object_id "
$s = $s + "join " + $CURRENT_DATABASE +  ".sys.change_tracking_tables c on c.object_id = t.object_id "
$SQL_tables_column = $s + "JOIN " + $CURRENT_DATABASE +  ".sys.schemas s ON t.[schema_id] = s.[schema_id]"

#-------functions---------------------------
function Invoke-Sqlcmd3 ($ServerInstance, $Query)
<#
	Chad Millers Invoke-Sqlcmd3
#>
{
	$QueryTimeout=1200
    $conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Trusted_Connection=True;"
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

#standard security version
function Invoke-Sqlcmd3_Std ($ServerInstance, $Database, $User, $Password ,$Query)
<#
	Chad Millers Invoke-Sqlcmd3
#>
{
	$QueryTimeout=1200
    $conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";database=" + $Database + ";User Id=" + $User + ";Password=" + $Password + ";"
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




function BuildScriptsOneTable ($database, $table, $colarray)
{
        #---loop start
        Write-Host 'database ' $CURRENT_DATABASE
        Write-Host 'table ' $table
        Write-Host 'columns ' $colarray
        # Now build the sql for deltas--------------------------------------
        $s = 'SET NOCOUNT ON' + $CRLF
        $s = $s + 'GO' + $CRLF  
        
        $s = $s + 'declare @synchid bigint' + $CRLF
        $s = $s + 'declare @max_synch bigint' + $CRLF
        

        #$s = $s + 'set @synchid = CHANGE_TRACKING_CURRENT_VERSION() -1;' + $CRLF
        $s = $s + 'set @synchid = CHANGE_TRACKING_CURRENT_VERSION();' + $CRLF
        $s = $s + 'set @max_synch = ?;'  + $CRLF
        $s = $s + "SELECT " + $CRLF
        $cnt = 0
        # ----columns loop start-------------------
        foreach ($k in $colarray)
        {
            if ($cnt -lt $colarray.Count)
            {
                if ($cnt -eq 0)
                {
                    $s = $s + 'ct.' + $k  + ',' + $CRLF
                }
                else
                {
                    $s = $s + 'p.' + $k  + ',' + $CRLF                 
                }
            }
            $cnt++
        }
        $s = $s + 'cast(CT.SYS_CHANGE_OPERATION as varchar(8000)) as ' +[char]39 + 'SYS_CHANGE_OPERATION' + [char]39 + ', ' +$CRLF
#        $s = $s + 'cast(CT.SYS_CHANGE_CONTEXT as varchar(8000)) as ' +[char]39 + 'SYS_CHANGE_CONTEXT' + [char]39 + ',' + $CRLF
        $s = $s + '@synchid as ' + [char]39 + 'LAST_SYNCH' + [char]39 + $CRLF       
        # -----columns loop end------
        $s = $s + ' FROM ' + $table + ' AS p'  + $CRLF
        $s = $s + 'RIGHT OUTER JOIN ' + $CRLF
        #$s = $s + 'CHANGETABLE(CHANGES ' + $table + ', @synchid) AS CT ON ' + $CRLF
        $s = $s + 'CHANGETABLE(CHANGES ' + $table + ', @max_synch) AS CT ON ' + $CRLF
        $s = $s + 'P.' + $colarray[0] + ' = CT.' + $colarray[0] + ' ' + $CRLF
        $s = $s + 'Where @synchid > @max_synch'  + $CRLF
        Write-Host $s
        $filename = $table.Replace('[', '')
        $filename = $filename.Replace(']', '')

        Set-Content ($CURRENT_DATABASE + '_' + $filename + '_' + 'DELTA_DATA.sql') $s     
        # -- end of deltas--------------------------------------------------      
}

function CreateDict
{
    #$p = Invoke-Sqlcmd3 ([char]34 + $CURRENT_SERVER + [char]34) $SQL_tables_column
    #Invoke-Sqlcmd3_Std ($ServerInstance, $Database, $User, $Password ,$Query)
    #use for $CURRENT_SERVER   = '10.111.242.35,1433'
    #$p = Invoke-Sqlcmd3_Std $CURRENT_SERVER $CURRENT_DATABASE $USER $PASSWORD $SQL_tables_column
    $p = Invoke-Sqlcmd3 $CURRENT_SERVER $SQL_tables_column
    $dict = @{}
    $alreadyprocessed = ""
    foreach ($k in $p)
    {
        if ($k.table -ne $alreadyprocessed)
        {
            $alreadyprocessed = $k.table
            foreach ($r in $p)
            {
                if ($r.table -eq $k.table)
                {
                        if (!$dict[$k.table])
                        {
                            $dict[$k.table] = $r.column
#                            $dict[$k.table] = $r.table
                        }
                        else
                        {
                            $dict[$k.table] = $dict[$k.table] + "," + $r.column                    
                        }
                }
            }
        }   
    }
    return $dict
}


function RunProcess
{
    $dict2 = CreateDict
#    $dict
    #keys are the tables. looping to create scripts for each
    foreach ($k in $dict2.Keys)
    {
        Write-Host "processing " $k
        #BuildScriptsOneTable $database, $table, $colarray
        $colarray = $dict2[$k].split(",")
        BuildScriptsOneTable $CURRENT_DATABASE $k $colarray
    }
}

RunProcess
