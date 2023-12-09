$threads = 4;
$server_count = $tsql_Prod_Servers_Result.Count; # List of objects to iterate through
$counter = 0;
$jobs = @();
$server_count = 10 # Remove this line
do {
    $running_job_count = (Get-Job -Name "BlitzIndex-*" | ? {$_.State -eq 'Running'}).count;
    if($running_job_count -lt $threads)
    {
        $srvObj = $tsql_Prod_Servers_Result[$counter];
        $ServerName = $srvObj.FriendlyName;
        $jobs += Start-Job -Name "BlitzIndex-$ServerName" -ScriptBlock $ScriptBlock;
        $counter = $counter + 1;
        Write-Host "Started job for $ServerName";
    }
    else {
        Start-Sleep -Seconds 10;
    }
}while($counter -lt $server_count);

$jobs | Wait-Job | Out-Null;

$failed_jobs = $jobs | Where-Object {$this.State -eq 'Failed'};
$passed_jobs = $jobs | Where-Object {$this.State -ne 'Failed'};

$out = $passed_jobs | Receive-Job;
$jobs | Remove-Job;
