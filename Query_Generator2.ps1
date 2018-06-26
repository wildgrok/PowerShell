<#
Query_Generator2.ps1
version in 
C:\Users\jorgebe\Documents\genesis\change_tracking_genesis

Created:        5/22/2018 from original 4/19/2018
Last Modified:
6/15/2018 big changes fixed detection of multiple rows
6/14/2018 fixed issue of missing last column
6/12/2018 fixed all, it creates procs for delta and table creation
5/22/2018 no need for mapping.txt


Creates set of queries for change tracking
- Scripts for table creation
- Script for proc creation (to be scheduled with desired frequency)



#>

#-------globals-----------------------------
#$path = 'C:\Users\jorgebe\Documents\genesis\change_tracking_genesis\deployment'
#$path = 'C:\Users\jorgebe\Documents\genesis\JackpotBlitz\Data Strategy Data Transfer Service\DEPLOYMENT'
$path = 'C:\Users\jorgebe\Documents\Data Sync Project - KT Srini\CHANGE_TRACKING_VERSION'

Set-Location $path
$CURRENT_DATABASE = "Offer_Change_Tracking"
$WEBMETHODS_DATABASE = "Offer_Change_Tracking"
$CURRENT_SERVER   = 'Ccluatshrddb1\uatsql2'
#$CURRENT_DATABASE = "Genesis_Breeze"
#$WEBMETHODS_DATABASE = "WM_AUDIT"
#$CURRENT_SERVER   = 'XXDEVSQL3'


$CRLF = [char]13 + [char]10

$s = "set nocount on select  b.name as 'table', a.name as 'column' from " + $CURRENT_DATABASE + ".sys.columns a "
$s = $s + "	join " + $CURRENT_DATABASE + ".sys.tables b on a.object_id = b.object_id join " + $CURRENT_DATABASE + ".sys.change_tracking_tables c on "
$SQL_tables_column = $s + "	c.object_id = b.object_id"

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

        # Build the sql for initial data load---------------
        # CHANGED to create tables with null
        
        $s = 'SET NOCOUNT ON' + $CRLF
        $s = $s + 'USE [' +  $WEBMETHODS_DATABASE + ']' + $CRLF
        $s = $s + 'if exists (select name from sys.tables where name = ' + [char]39 + $CURRENT_DATABASE + '_' + $table + [char]39 + ')'  + $CRLF
        $s = $s + "drop table " + $CURRENT_DATABASE + '_' + $table + $CRLF
        $s = $s + 'CREATE TABLE ' + $CURRENT_DATABASE + '_' + $table + '('  + $CRLF       
        $cnt = 0
        # ----columns loop start-------------------
        foreach ($k in $colarray)
        {
#            Write-Host "col:" $k $cnt.ToString()
            if ($cnt -lt $colarray.Count)
            {
                $s = $s + $k + ' varchar(8000) null ,' + $CRLF               
            }
           $cnt++
        }
        $s = $s + 'SYS_CHANGE_OPERATION varchar(8000) null,'  + $CRLF
#        $s = $s + 'SYS_CHANGE_CONTEXT varchar(8000) null ,' + $CRLF
        $s = $s + 'LAST_SYNCH bigint null )' + $CRLF
        # -----columns loop end------
        Write-Host $s
        Set-Content ($CURRENT_DATABASE + '_' + $table + '_' + 'table_creation.sql') $s
        # --- end of initial data load--------------------------------------
        
        
        # Now build the sql for deltas--------------------------------------
        $s = 'SET NOCOUNT ON' + $CRLF
        $s = $s + 'USE [' + $CURRENT_DATABASE + ']' + $CRLF
        $s = $s + 'if exists (select name from sysobjects where name = ' + [char]39 + 'USP_DELTA_' + $table + [char]39 + ')'  + $CRLF
        $s = $s + 'drop proc USP_DELTA_' + $table + $CRLF
        $s = $s + 'GO' + $CRLF
        $s = $s + 'CREATE PROC [USP_DELTA_' + $table + ']' + $CRLF
        $s = $s + 'as ' + $CRLF
        $s = $s + 'SET NOCOUNT ON' + $CRLF        
        $s = $s + 'declare @synchid bigint' + $CRLF
        $s = $s + 'declare @max_synch bigint' + $CRLF
        $s = $s + 'set @synchid = CHANGE_TRACKING_CURRENT_VERSION();' + $CRLF
        $s = $s + 'select @max_synch = max([LAST_SYNCH]) from ' + $WEBMETHODS_DATABASE + '.dbo.' + $CURRENT_DATABASE + '_' + $table + $CRLF
        $s = $s + 'if (@max_synch is null) set @max_synch = -1' + $CRLF
#        $s = $s + 'if (@synchid > @max_synch) ' + $CRLF
#        $s = $s + 'begin' + $CRLF
        $s = $s + 'INSERT INTO ' + $WEBMETHODS_DATABASE + '.dbo.' + $CURRENT_DATABASE + '_' + $table + $CRLF   
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
        $s = $s + 'cast(CT.SYS_CHANGE_OPERATION as varchar(8000)) as ' +[char]39 + 'SYS_CHANGE_OPERATION' + [char]39 + ',' +$CRLF
#        $s = $s + 'cast(CT.SYS_CHANGE_CONTEXT as varchar(8000)) as ' +[char]39 + 'SYS_CHANGE_CONTEXT' + [char]39 + ',' + $CRLF
        $s = $s + '@synchid as ' + [char]39 + 'LAST_SYNCH' + [char]39 + $CRLF       
        # -----columns loop end------
        $s = $s + ' FROM [dbo].[' + $table + '] AS p'  + $CRLF
        $s = $s + 'RIGHT OUTER JOIN ' + $CRLF
        $s = $s + 'CHANGETABLE(CHANGES [dbo].[' + $table + '], @max_synch) AS CT ON' + $CRLF
        $s = $s + 'P.[' + $colarray[0] + '] = CT.[' + $colarray[0] + ']' + $CRLF
        $s = $s + 'WHERE @synchid > @max_synch' +  $CRLF
#        $s = $s + 'end' + $CRLF
        Write-Host $s
        Set-Content ($CURRENT_DATABASE + '_' + $table + '_' + 'DELTA_DATA.sql') $s     
        # -- end of deltas--------------------------------------------------      
}

function CreateDict
{
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
