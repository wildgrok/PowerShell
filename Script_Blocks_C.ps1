# Script_Blocks_C.ps1
# This is a program importing all code blocks
. C:\WORKFLOWS\Script_Blocks_B.ps1 # This imports the GetBackupInfo script block

# $bkfile = '\\SQLBACKUPS\AdventureWorks2008R2.bak'
# $server = 'SQLSERVERNAME'

$server = 'CCLDEVSQL4\DEVSQL2'
# $bkfile = '\\NETSHARE\DBNAME_backup_2019_12_11_000029_6076771.bak'
$bkfile = '\\Ccldevsql4\devsql2\SQLBACKUPS\SQLBackupUser\ZZZ_Deleteme_1_backup2.bak'




$d = (Invoke-Command -ScriptBlock $GetBackupInfo -ArgumentList ($server, $bkfile))
"logicalname"
$d.filelist.logicalname
"physicalname"
$d.filelist.physicalname

"This should not work: I did not import ExecuteSql in this scope:"
$query = 'select top 1 [FirstName],[LastName],[EmailPromotion] from Person.Person'
$query
$database = 'AdventureWorks2008R2'
$database
# same results using Invocke-Command
# $r = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $query, $database))
$r = & $ExecuteSQL $server $query $database
$r


