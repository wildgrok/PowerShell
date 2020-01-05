# https://www.dhb-scripting.com/Forums/posts/t58-PowerShell-and-Getting-Basic-FileInfo-with-a-Timeout

function Get-DirFileInfo
{
    <#
    .SYNOPSIS
    Function to get file info from the "dir" command.
    .DESCRIPTION
    Function to get file info from the "dir" command.  This function calls
    Start-ProcessWaitTimeout so it will only wait as long as the timeout.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Computer,
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    # Create the Object
    $Obj = [PSCustomObject]@{
        Computer = $Computer
        Online = $null
        FilePath = $FilePath
        DirPath = $null
        FileName = $null
        Exists = $null
        Size = $null
        LastModifiedDate = $null
        CmdResult = $null
    }
    # Change the Directory path to the UNC path
    $Obj.DirPath = "\\$($Computer)\$($FilePath.Substring(0,$FilePath.LastIndexOf("\")).Replace(":","$"))"
    # Set the File Name
    $Obj.FileName = $FilePath.Split("\")[-1]
    ## CHECK PING STATUS - RETURN IF OFFLINE
    $pingStatus = ping -n 1 -4 $computer
    if ($?) {
        if ($pingStatus -match "unreachable" -or $pingStatus -match "could not find host" -or $pingStatus -match "timed out") {
            $Obj.Online = $false
            Return $Obj
        } else {
            $Obj.Online = $true
        }
    } else {
        $Obj.Online = $false
        Return $Obj
    }
    # Setup the Command
    $Cmd = "C:\Windows\System32\cmd.exe"
    $CmdArgs = @("/c","dir","/-c","""$($Obj.DirPath)\$($Obj.FileName)""")
    # Run the Command
    $Obj.CmdResult = Start-ProcessWaitTimeout -Computer $Computer -CmdLine $Cmd -CmdLineArgs $CmdArgs -Timeout 10
    # Loop throught the StdOut
    foreach ($i in $Obj.CmdResult.ProcessStdOut.Split("`n")) {
        if ($i -match "(?<Date>\d\d/\d\d/\d\d\d\d)\s+(?<Time>\d\d:\d\d\s\w\w)\s+(?<Size>.*)\s+($($Obj.FileName)).*") {
            $Obj.Exists = $true
            $Obj.LastModifiedDate = (Get-Date("$($Matches.Date) $($Matches.Time)"))
            $Obj.Size = [int]$($Matches.Size)
        }
    }
    # Return the Object
    Return $Obj
}
# Example
Get-DirFileInfo -Computer "Computer1" -FilePath "C:\Program Files\7-Zip\7z.exe"