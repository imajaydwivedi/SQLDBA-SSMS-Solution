# Test RSJob with Timeout & Incremental Status Update
@(1,2,2,4,5,6,7,8,9,10,30,60,90) | Start-RSJob -Name {"Test_$_"} -Throttle 2 -ScriptBlock { start-sleep -Seconds $_ }
$status_report_seconds = 10;
$job_timeout_minutes = 10

# Get all the running jobs
$job_start_time = Get-Date
$jobs = Get-RSJob | ? {$_.Name -like 'Test_*'}

"Jobs started.." | Write-Output
$jobs | ft -AutoSize

while($true)
{
    $time_start = Get-Date
    $jobs | Wait-RSJob -ShowProgress -Timeout $status_report_seconds | Out-Null
    $time_end = Get-Date

    $ts = New-TimeSpan -Start $time_start -End $time_end
    if($ts.TotalSeconds -le 5) { # If no jobs in progress
        break;
    }
    else {
        "Jobs progress.." | Write-Output
        $jobs | ft -AutoSize
    }
    if((New-TimeSpan -Start $job_start_time -End (Get-Date)).TotalMinutes -ge $job_timeout_minutes) { # If jobs ran longer than $job_timeout_minutes
        break;
        Write-Error "PSJobs could not complete within `$job_timeout_minutes ($job_timeout_minutes) threshold"
    }
}

"`nFinal Job State.." | Write-Output
$jobs | ft -AutoSize

$jobs | Stop-RSJob
$jobs | Remove-RSJob
