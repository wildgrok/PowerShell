#$strCategory = "computer"
#$objDomain = New-Object System.DirectoryServices.DirectoryEntry
#$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
#$objSearcher.SearchRoot = $objDomain
#$objSearcher.Filter = ("(objectCategory=$strCategory)")
#$colProplist = "name"
#foreach ($i in $colPropList){$objSearcher.PropertiesToLoad.Add($i)}
#$colResults = $objSearcher.FindAll()
#$i = 0
#foreach ($objResult in $colResults)
#{
#
#	$objComputer = $objResult.Properties; $objComputer.name
#	$i++
#}
#$i


$strFilter = "computer"
 
$objDomain = New-Object System.DirectoryServices.DirectoryEntry
 
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchRoot = $objDomain
$objSearcher.SearchScope = "Subtree" 
$objSearcher.PageSize = 100000 

$objSearcher.Filter = "(objectCategory=$strFilter)"

$colResults = $objSearcher.FindAll()

foreach ($i in $colResults) 
    {
        $objComputer = $i.GetDirectoryEntry()
		$Name = $objComputer.Name.ToString()
		if (  $Name.StartsWith('CCLTST') -or $Name.StartsWith('CCLUAT') -or $Name.StartsWith('CCLDEV') -or $Name.StartsWith('CCLPRD')  -and ($Name.Contains('DB') -or $Name.Contains('SQL') )) 
		{
#        	Get-WMIObject Win32_BIOS -computername $Name -ErrorAction SilentlyContinue 
		Write-Host 	$Name
		}
		
    }