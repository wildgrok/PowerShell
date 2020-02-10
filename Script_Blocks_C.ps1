# Script_Blocks_C.ps1
# This is a program importing all code blocks

# This calls the GetBackupInfo script block
. C:\CODECAMP\Script_Blocks_B.ps1

$bkfile = '\\ccldevsql4\g$\DEVSQL2\SQLBACKUPS\AdventureWorks2008R2.bak'
$server = 'CCLDEVSQL4\DEVSQL2'

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
$r = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $query, $database))
$r
