Workflow Test-Suspend
{
    $a = Get-Date
    Suspend-Workflow
    (Get-Date)- $a
}
<#
The Suspend-Workflow temporarily stops the workflow and returns 
a job object that represents the workflow job. 
A job object is returned even if you didn't run the workflow as a job. 
For example, such as by using the AsJob workflow common parameter. 
The job state is Suspended.

After running Test-suspend

Id     Name            PSJobTypeName   State         HasMoreData     Location             Command
--     ----            -------------   -----         -----------     --------             -------
19     Job19           PSWorkflowJob   Suspended     True            localhost            test-...


#>

<#
To resume the workflow job, use the Resume-Job cmdlet. 
The Resume-Job cmdlet returns the workflow job object immediately, 
even though it might not yet be resumed.

Id     Name            PSJobTypeName   State         HasMoreData     Location             Command
--     ----            -------------   -----         -----------     --------             -------
9     Job19           PSWorkflowJob   Running       True            localhost            test-...

#>

<#
Note: after the call to resume-job, the job status changes from 
Sustended to Running
#>

<#
Note: after the call to get-job, the job status changes from 
Running to Completed

Id     Name            PSJobTypeName   State         HasMoreData     Location             Command
--     ----            -------------   -----         -----------     --------             -------
19     Job19           PSWorkflowJob   Completed     True            localhost            test-...

#>

<#
From the book:
To get the output of a workflow job, use the Receive-Job cmdlet. 
The output shows that the workflow resumed at the command 
that followed the Suspend-Workflow cmdlet. 
The value of the $a variable, which was populated before the suspension, 
is available to the workflow when it resumes.

Translation:
At this point the job completed. But if you need to get output of the job
you have to use receive-job
#>

<#
PS C:\CODECAMP> receive-job -id 21


Days              : 0
Hours             : 0
Minutes           : 22
Seconds           : 48
Milliseconds      : 334
Ticks             : 13683344704
TotalDays         : 0.0158372045185185
TotalHours        : 0.380092908444444
TotalMinutes      : 22.8055745066667
TotalSeconds      : 1368.3344704
TotalMilliseconds : 1368334.4704
PSComputerName    : localhost
#>

