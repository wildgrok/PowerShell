<#
ListInstalledPrograms.ps1
Version in CCLDEVSHRDDB1, e:\powershell
Laste edited:
6/6/2019 (for sql server)
#>

function ListDrives($Servername)
{
    ForEach-Object `
    {
        get-wmiobject -computername $Servername win32_logicaldisk `
        | select-object systemname, deviceID, Size, Freespace, DriveType `
    }
}

function FindProgram( $strComputer, $pname)
{

	$colItems = get-wmiobject -class "Win32_Product" -namespace "root\CIMV2" -computername $strComputer

	foreach ($objItem in $colItems) 
	{
		if ($objItem.Name.Contains($pname))
		{
			Write-Host $objItem.Name
		}
	#      write-host "Caption: " $objItem.Caption
	#      write-host "Description: " $objItem.Description
	#      write-host "Identifying Number: " $objItem.IdentifyingNumber
	#      write-host "Installation Date: " $objItem.InstallDate
	#      write-host "Installation Date 2: " $objItem.InstallDate2
	#      write-host "Installation Location: " $objItem.InstallLocation
	#      write-host "Installation State: " $objItem.InstallState
	#      write-host "Name: " $objItem.Name
	#      write-host "Package Cache: " $objItem.PackageCache
	#      write-host "SKU Number: " $objItem.SKUNumber
	#      write-host "Vendor: " $objItem.Vendor
	#      write-host "Version: " $objItem.Version
	#      write-host
	}
}



function ProcessServers($Serverlist)
{
    $outmessage = ""
    $fullreport = ""
    $links      = ""
	$c = 0
    $Computers = Get-Content -Path $Serverlist;
    foreach ($z in $Computers) 
    {	
		
        if ($z -gt "" -and $z[0] -ne "#")
        {
            $fullreport = $fullreport + "Server : " + $z + [char]10
			$erroractionpreference = "SilentlyContinue"
            $a = ListDrives($z)
            foreach ($k in $a)
            {
                if ($k.DriveType -eq 3 -and $k.size -ne $null)
                {
					$j = ($k.deviceid).Replace(":", "")
					$s = "\\" + $k.systemname + "\" + $j + "$"
					$z = Get-ChildItem $s -Directory -Recurse
					foreach ($x in $z)
					{
						$y = $x.ToString()
						if ($y.Contains("SQL"))
						{
							Write-Host $k.systemname " has SQL:  " $y
						}
					}
					
                }
            }
        
        }
    }  
}

$strComputer = "CORPUATSQL1"
$pname = "SQL"

FindProgram $strComputer, $pname


#ProcessServers "c:\Users\jorgebe\Documents\powershell\ListInstalledPrograms.txt"
