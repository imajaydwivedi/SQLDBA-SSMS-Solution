$Scriptblock = {
    param($Name)
    New-Item -Name $Name -ItemType File
}

$MaxThreads = 5
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$RunspacePool.Open()
$Jobs = @()

1..10 | Foreach-Object {
	$PowerShell = [powershell]::Create()
	$PowerShell.RunspacePool = $RunspacePool
	$PowerShell.AddScript($ScriptBlock).AddArgument($_)
	$Jobs += $PowerShell.BeginInvoke()
}

while ($Jobs.IsCompleted -contains $false) {
	Start-Sleep 1
}