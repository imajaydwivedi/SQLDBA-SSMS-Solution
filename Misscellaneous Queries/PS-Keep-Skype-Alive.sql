$ScriptBlock = {
    $fileName = 'c:\temp\keep_my_system_active.txt';

    if (-not [System.IO.File]::Exists($fileName) ) {
        New-Item $fileName -ItemType file
    }

    notepad  $fileName;
    Start-Sleep -Seconds 5;

    while($true) {
        Get-Process *notepad* | Where-Object {$_.MainWindowTitle -eq 'keep_my_system_active.txt - Notepad'} | Stop-Process;
        Start-Sleep -Seconds 210
        notepad  $fileName;
        Start-Sleep -Seconds 5;
    }
}

Start-Job -Name "keep_my_system_active" -ScriptBlock $ScriptBlock;