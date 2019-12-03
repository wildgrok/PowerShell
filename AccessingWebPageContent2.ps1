# Accessing Web Page Content
# Beginning with PowerShell 3.0, the cmdlet Invoke-WebRequest can download web page content quite easily. This would scrape all links from www.powertheshell.com for example:
# requires -Version 3
# version in ccdevshrddb1\e$\powershell
# last modified 11/26/2019

# Functions-------------------
function Invoke-Sqlcmd3
{
    param(
    [string]$ServerInstance,
    [string]$Query
    )
	$QueryTimeout=30
    $conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Integrated Security=True"
	$conn.ConnectionString=$constring
    $conn.Open()
	if($conn)
    {
    	$cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
    	$cmd.CommandTimeout=$QueryTimeout
    	$ds=New-Object system.Data.DataSet
    	$da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
    	[void]$da.fill($ds)
    	$conn.Close()
    	$ds.Tables[0]
	}
}
# end of Functions------------


$SQLSERVER = 'CCLDEVSHRDDB1\DEVSQL2'
$DATABASE  = 'Master_Application_List'

$OUTFILE = 'E:\POWERSHELL\dbadocs.txt'

$s = 'truncate table [' + $DATABASE + '].dbo.[DBA_SHARED_DOCS]'
Invoke-Sqlcmd3 $SQLSERVER $s

$url = 'http://cclportal.carnival.com/isportal/sqldba/Documents/Forms/AllItems.aspx?RootFolder=%2Fisportal%2Fsqldba%2FDocuments%2FSQL%20Whitepapers%2C%20E%2DBooks%2C%20Tips%20and%20useful%20information&FolderCTID=0x012000B1C98D4195461F4785CB3631EC02AD01&View=%7BCAA44DFE%2DEAB6%2D4BE9%2D86BE%2D7FCC2C95A3C9%7D' 


# THIS IS THE ONE THAT WORKS!!!
$page = Invoke-WebRequest -Uri $url  -UseBasicParsing -UseDefaultCredential
# $page.RawContent

Set-Content -path $OUTFILE $page.RawContent

$tag = '"FileLeafRef": "'
$isfolder = ''
$filedata = Get-Content $OUTFILE
foreach ($k in $filedata)
{
    if ($k.StartsWith($tag))
    {
        $m = $k.replace($tag, '').replace('",', '')
        # if ($m.Contains('.*')) { $isfolder = 'N'}
        if ($m -like '*.*') { $isfolder = 'N'}
        else {$isfolder = 'Y'}
        $s = 'INSERT INTO [' + $DATABASE + '].[dbo].[DBA_SHARED_DOCS] ([DocName] ,[Isfolder]) '
        $s = $s + "VALUES ('" + $m + "','" + $isfolder + "')"
        Invoke-Sqlcmd3 $SQLSERVER $s
    }

}

 