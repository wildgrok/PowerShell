<#
ScriptAllObjects.ps1
Scripts all objects in all dbs in a server
Tables names produced with execution order 
Last modified: 10/31/2018
#>


function Invoke-Sqlcmd3 ($ServerInstance,$Query, $Database)
<#
	Chad Millers Invoke-Sqlcmd3
#>
{
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
        $ds
    	$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    	[void]$da.fill($ds)
    	$conn.Close()
    	$ds.Tables[0]
	}
}

# Initial version: https://stackoverflow.com/questions/40388903/how-to-list-tables-in-their-dependency-order-based-on-foreign-keys
$SQLTables =
@"
with        cte (lvl,object_id,name)
            as 
            (
                select      1
                           ,tb.object_id
                           --,tb.name as 'name'
						    ,s.name + '.' + tb.name AS 'name' 
                from        sys.tables as tb
				JOIN sys.schemas AS s 
				ON tb.[schema_id] = s.[schema_id] 
                where       tb.type_desc       = 'USER_TABLE'
                        and tb.is_ms_shipped   = 0
                union all
                select      cte.lvl + 1
                           ,t.object_id
                           --,t.name
						    ,s.name + '.' + t.name AS 'name' 
                from       cte
                join  sys.tables  as t
                on  exists
                (
                     select      null
                     from        sys.foreign_keys    as fk
                     where       fk.parent_object_id     = t.object_id 
                     and fk.referenced_object_id = cte.object_id
                )
				
                and cte.lvl < 30
				JOIN sys.schemas AS s
				ON t.[schema_id] = s.[schema_id] 
                and t.object_id <> cte.object_id
                where       
					t.type_desc = 'USER_TABLE'      
                    and t.is_ms_shipped = 0
            )

select      name
           ,max (lvl)   as dependency_level
from        cte
group by    name
order by    dependency_level
           ,name
;
"@

function RenameTable($tablename, $tablelist)
{
        foreach ($k in $tablelist)
        {
            if ($k.name -eq $tablename)
            {
                return $k.dependency_level.ToString().PadLeft(4, "0") + " - " + $k.name
            }
        }  
    return ($tablename + " - not found")
}

#==========================PROGRAM STARTS HERE==========================================


$date_ = (date -f yyyyMMdd)
#$ServerName = "." #If you have a named instance, you should put the name. 
$ServerName = "CCLDEVSQL1\DEVSQL1" #If you have a named instance, you should put the name. 
$path = "c:\temp\"+"$date_"

 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
$serverInstance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
$IncludeTypes = @("Tables","StoredProcedures","Views","UserDefinedFunctions", "Triggers") #object you want do backup. 
$ExcludeSchemas = @("sys","Information_Schema")
$so = new-object ('Microsoft.SqlServer.Management.Smo.ScriptingOptions')
$ServerDbs = @{}
 
$dbs=$serverInstance.Databases #you can change this variable for a query for filter yours databases.
foreach ($db in $dbs)
{
       $dbname = "$db".replace("[","").replace("]","")
       Write-Host "===============" $dbname "====================================="
       $SQLTables2 = "SET NOCOUNT ON; USE " + $dbname + ";" + $SQLTables
       $ServerDbs[$dbname] = Invoke-Sqlcmd3 $SERVERNAME $SQLTables $dbname     
       $dbpath = "$path"+ "\"+"$dbname" + "\"
    if ( !(Test-Path $dbpath))
           {$null=new-item -type directory -name "$dbname"-path "$path"}
 
       foreach ($Type in $IncludeTypes)
       {
              $objpath = "$dbpath" + "$Type" + "\"
         if ( !(Test-Path $objpath))
           {$null=new-item -type directory -name "$Type"-path "$dbpath"}
              foreach ($objs in $db.$Type)
              {
                     If ($ExcludeSchemas -notcontains $objs.Schema) 
                      {
                           $ObjName = "$objs".replace("[","").replace("]","") 
                           if ($Type -eq "Tables")
                           {
                                $ObjName = RenameTable $ObjName $ServerDbs[$dbname]
                           }
                           $OutFile = "$objpath" + "$ObjName" + ".sql"
                           $objs.Script($so)+"GO" | out-File $OutFile
                      }
              }
       }  
}
#test print
#$ServerDBs
