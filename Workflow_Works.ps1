workflow Run-Workflow 
{ 

  InlineScript 
  { 
    Write-Output "Started parallel process"	
    Get-Date
  }	

  parallel
  {
    Start-Sleep -s 60
    Start-Sleep -s 35
    Start-Sleep -s 25
  }

  InlineScript 
  { 
    Write-Output "Completed parallel process"	
    Get-Date
  }	

}

Run-Workflow