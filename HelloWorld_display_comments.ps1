# we create the workflow
workflow HelloWorld
{
    # this does not work
    # Write-Host "The workflow starts here"
    InlineScript
    {
        "Before starting parallel process"
        Get-Date
    }

    # "Ok not using Write-host here this works"

    parallel 
    {
        "Starting first sleep"
        Start-Sleep -s 15
        "Starting second sleep"
        Start-Sleep -s 10
        "Starting third sleep"
        Start-Sleep -s 5
    }

    InlineScript
    {
        "After completing parallel process"
        Get-Date       
    }
}

# and we execute the workflow
HelloWorld