<#
Hello Ajay,
   Please start the robocopy process of moving the contents of the E:\ , F:\ and G:\ drives to I:\, J:\ and K:\ respectively.

   We can skip .mdf files, .ldf files, .csq files and .bak files for now. THis will be the first move before the cutover on 10/26

  We will do another robocopy exercise on 10/26 to cover the deltas in the folders after we stop all the services on 10/26

#>
#$PubServer = Read-Host "Enter ServerName" 
$PubServer = 'YOURTESTSERVER'
#$Pub = New-PSSession -ComputerName $PubServer -Name $PubServer
#Enter-PSSession $Pub

# Session 01 - Copy Everything except mdf/ldf/csq/bak
# Session 02 - Copy Delta except mdf/ldf/csq/bak
# Session 03 - Copy mdf/ldf/csq/bak

[System.Collections.ArrayList]$DriveMapping = @()
$RoboCopyScript = 'C:\temp\RITM12345_RoboCopy_Scripts.txt'
if(Test-Path $RoboCopyScript){Remove-Item $RoboCopyScript}
New-Item $RoboCopyScript;

$obj = New-Object -TypeName psobject -Property @{ 'Source' = 'E:\'; 'Destination' = 'I:\' }
$DriveMapping.Add($obj) | Out-Null;

$obj = New-Object -TypeName psobject -Property @{ 'Source' = 'F:\'; 'Destination' = 'J:\' }
$DriveMapping.Add($obj) | Out-Null;

$obj = New-Object -TypeName psobject -Property @{ 'Source' = 'G:\'; 'Destination' = 'K:\' }
$DriveMapping.Add($obj) | Out-Null;

foreach($item in $DriveMapping) {
    $src = $item.Source; $tgt = $item.Destination;
    $rOptions = '/e /zb /copy:DATSOU /dcopy:DAT /sl /MT:8';
    $rExcludeFile = '/xf *.mdf *.ldf *.csq *.bak';
    $rIncludeFile = '/if *.mdf *.ldf *.csq *.bak';
    $rFileOptions = '/v /log+:c:\temp\RITM12345_RoboCopy_Logs.txt /tee'
    $rChangedFiles = '/it'
    $rWhatIf = '/l'

    # Session 01 - Copy Everything except mdf/ldf/csq/bak (Same command will work for Delta)
    "Write-Output '# Session 01 - [$src => $tgt] - Copy Everything except mdf/ldf/csq/bak'" | Out-File -FilePath $RoboCopyScript -Append;
    "robocopy $src $tgt $rExcludeFile $rFileOptions $rChangedFiles $rOptions" +" $rWhatIf" | Out-File -FilePath $RoboCopyScript -Append;
    "" | Out-File -FilePath $RoboCopyScript -Append

    # Session 02 - Copy mdf/ldf/csq/bak
    "Write-Output '# Session 02 - [$src => $tgt] - Copy mdf/ldf/csq/bak'" | Out-File -FilePath $RoboCopyScript -Append;
    "robocopy $src $tgt $rIncludeFile $rFileOptions $rChangedFiles $rOptions" +" $rWhatIf" | Out-File -FilePath $RoboCopyScript -Append;
    "" | Out-File -FilePath $RoboCopyScript -Append
}

notepad $RoboCopyScript