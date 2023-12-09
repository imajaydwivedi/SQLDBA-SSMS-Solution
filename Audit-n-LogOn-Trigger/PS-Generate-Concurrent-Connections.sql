#$con = New-DbaConnectionString -SqlInstance localhost -ClientName 'dbatools-test' -Database master

$scriptBlock = {
    Invoke-DbaQuery -SqlInstance $Using:con `
				-Query "waitfor delay '00:01:00'; SELECT getutcdate() as time, @@servername as srv_name, SUSER_NAME() as login_name, PROGRAM_NAME() as program_name;" `
                -As DataTable
    }

$jobs = @()
foreach($no in 1..50) {
    "Loop no -> $no" | Write-Host -ForegroundColor Yellow 
    $jobs += Start-Job -ScriptBlock $scriptBlock -Name "Job_$no" 
}

$jobs | Remove-Job -Force