# Script_Blocks_B.ps1
# It uses ExecuteSQL from Script_Blocks_A.ps1
$GetBackupInfo = 
{
    param ($server, $backupfile)
    # Use this all the time to organize your scripts
    # Be nice and add a comment on what you are importing
    . C:\WORKFLOWS\Script_Blocks_A.ps1       # Brings ExecuteSql
<#
Sample use:
$server = 'SQLSERVERNAME'
$bkfile = '\\NETSHARE\ZZZ_Deleteme_1_backup2.bak'
$d = & $GetBackupInfo $server $bkfile
Using some properties:
$d.filelist.logicalname gives
DBNAME_Data
DBNAME_Log
#>
	$dct = @{}
    $filelist 	= 'SET NOCOUNT ON RESTORE FILELISTONLY FROM DISK = ' + [char]39 + $backupfile + [char]39
    # option 1
    # $dct['filelist'] = (Invoke-Command -ScriptBlock $ExecuteSQL -ArgumentList ($server, $filelist, "master"))
    # option 2
    $dct['filelist'] = & $ExecuteSQL $server $filelist "master"
	return $dct
}
"Script_Blocks_B.ps1 was called"

$server = 'CCLDEVSQL4\DEVSQL2'
# $bkfile = '\\NETSHARE\DBNAME_backup_2019_12_11_000029_6076771.bak'
$bkfile = '\\Ccldevsql4\devsql2\SQLBACKUPS\SQLBackupUser\ZZZ_Deleteme_1_backup2.bak'
$d = & $GetBackupInfo $server $bkfile
$d.filelist.logicalname



