# How To Log Off Windows Users Remotely With PowerShell
$Servers = @('YourServerName')

$scriptBlock = {
    $ErrorActionPreference = 'Stop'
 
    try {
        ## Find all sessions matching the specified username
        $sessions = quser | Where-Object {$_ -match 'adwivedi'}
        ## Parse the session IDs from the output
        $sessionIds = ($sessions -split ' +')[2]
        Write-Host "Found $(@($sessionIds).Count) user login(s) on computer."
        ## Loop through each session ID and pass each to the logoff command
        $sessionIds | ForEach-Object {
            Write-Host "Logging off session id [$($_)]..."
            logoff $_
        }
    } catch {
        if ($_.Exception.Message -match 'No user exists') {
            Write-Host "The user is not logged in."
        } else {
            throw $_.Exception.Message
        }
    }
}

foreach($srv in $Servers)
{
    Write-Host "checking $srv.." -ForegroundColor Yellow;
    try {
    Invoke-Command -ComputerName $srv -ScriptBlock $scriptBlock -ErrorAction Continue
    }
    catch {
        Write-Host "Error $srv.." -ForegroundColor Red;
    }
}
