#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.35
# Created on:   10/14/2019 5:17 PM
# Created by:   
# Organization: 
# Filename:     
#========================================================================


#https://www.reddit.com/r/PowerShell/comments/5ruldk/learning_ps_workflow_output_to_file/
<#
Correct, you might be able to get away with writing to the file like that, 
but chances are you will run into contention. 
You would want to avoid using a text file to store things that you can easily utilize 
the pipeline for or store in-memory for performance reasons anyway. 
Here's a basic example with some of your code commented out:
#>
workflow TestCon {
    param (
        [string[]]$Computers#, $SiteCode, $HostsFile
    )
    #$Computers = Get-Content .\$SiteCode\$HostsFile

    foreach -parallel ($computer in $computers){
        if (Test-Connection -ComputerName $computer -Count 1 -ErrorAction SilentlyContinue -Quiet){
            #Out-File .\$SiteCode\$($SiteCode + "Scan.txt") -Append
            $onlineStatus = $true
        }
        else{
            #Out-File .\$SiteCode\$($SiteCode + "NoPing.txt") -Append
            $onlineStatus = $false
        }
            [pscustomobject]@{'Computer'=$computer;'Online'=$onlineStatus}
    }
}

$resultList = New-Object System.Collections.Generic.List[object]

TestCon -Computers @("localhost","server1","server2","fakeComputer","localhost","server3") | ForEach-Object {$resultList.Add($_); $_ } | Where-Object {$_.Online } | ForEach-Object {"I should do something with $($_.Computer)"}

$resultList | Select Computer, Online