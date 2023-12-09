/*	Combine multiple PerfMon files into One
*/

$sqlDiagOutputFolder = 'H:\Performance-Issues\Data-Collections\<<ServerFolderName>>';
$perfmonFiles = Get-ChildItem $sqlDiagOutputFolder | Where-Object {$_.Extension -eq '.BLG'};

$AllArgs = @();
$combinedFile = "$sqlDiagOutputFolder\SQLDIAG_Combined.BLG";
for($counter=0;$counter -lt $perfmonFiles.Count;$counter++) {
    New-Variable -Name "blgFile$counter" -Value $perfmonFiles[$counter].FullName -Force;
    $AllArgs += $perfmonFiles[$counter].FullName;
}
$AllArgs += @('-f', 'bin', '-o',  $combinedFile);

& 'relog.exe' $AllArgs
#$AllArgs