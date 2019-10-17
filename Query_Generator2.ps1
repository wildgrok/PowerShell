
#﻿Query_Generator2.ps1
#version in 
#C:\Users\jorgebe\Documents\powershell
#Last Modified:
#10/17/2019: fixed issue with $SQL_tables_column query
#10/16/2019: changed for select only, no procs 



#-------globals-----------------------------
#$path = 'C:\Users\jorgebe\Documents\genesis\change_tracking_genesis\deployment'
#$path = 'C:\Users\jorgebe\Documents\genesis\JackpotBlitz\Data Strategy Data Transfer Service\DEPLOYMENT'
$path = 'C:\Users\jorgebe\Documents\powershell'

Set-Location $path
$CURRENT_DATABASE = "TableGames"
$WEBMETHODS_DATABASE = "TableGames"
$CURRENT_SERVER   = 'CCLDEVSBXDB1\CCLDEVSBXDB1'
#$CURRENT_DATABASE = "Genesis_Breeze"
#$WEBMETHODS_DATABASE = "WM_AUDIT"
#$CURRENT_SERVER   = 'XXDEVSQL3'


$CRLF = [char]13 + [char]10

$s = "select  (s.name + '.' + t.name) as 'table', a.name as 'column' from " + $CURRENT_DATABASE + ".sys.columns a "
$s = $s + "join " + $CURRENT_DATABASE +  ".sys.tables t on 	a.object_id = t.object_id "
$s = $s + "join " + $CURRENT_DATABASE + ".sys.change_tracking_tables c on c.object_id = t.object_id "
$s = $s + "JOIN " + $CURRENT_DATABASE + ".sys.schemas s ON t.[schema_id] = s.[schema_id]"
$SQL_tables_column = $s


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


function BuildScriptsOneTable ($database, $table, $colarray)
{
        #---loop start
        Write-Host 'database ' $CURRENT_DATABASE
        Write-Host 'wm database ' $WEBMETHODS_DATABASE
        Write-Host 'table ' $table
        Write-Host 'columns ' $colarray
        # Now build the sql for deltas--------------------------------------
        $s = 'SET NOCOUNT ON' + $CRLF
        $s = $s + 'GO' + $CRLF    
        $s = $s + 'declare @synchid bigint' + $CRLF
        $s = $s + 'set @synchid = CHANGE_TRACKING_CURRENT_VERSION() -1;' + $CRLF
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
        $s = $s + 'CHANGETABLE(CHANGES ' + $table + ', @synchid) AS CT ON ' + $CRLF
        $s = $s + 'P.' + $colarray[0] + ' = CT.' + $colarray[0] + ' ' + $CRLF
        Write-Host $s
        Set-Content ($CURRENT_DATABASE + '_' + $table + '_' + 'DELTA_DATA.sql') $s     
        # -- end of deltas--------------------------------------------------      
}

function CreateDict
{
    $p = Invoke-Sqlcmd3 ([char]34 + $CURRENT_SERVER + [char]34) $SQL_tables_column
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


function Process
{
    $dict = CreateDict
#    $dict
    #keys are the tables. looping to create scripts for each
    foreach ($k in $dict.Keys)
    {
        Write-Host "processing " $k
        #BuildScriptsOneTable $database, $table, $colarray
        $colarray = $dict[$k].split(",")
        BuildScriptsOneTable $CURRENT_DATABASE $k $colarray
    
    }
}

Process
