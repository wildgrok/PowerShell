# we create the workflow
workflow HelloWorld
{
    InlineScript
    {
        "Before starting parallel process"
        Get-Date
    }

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


