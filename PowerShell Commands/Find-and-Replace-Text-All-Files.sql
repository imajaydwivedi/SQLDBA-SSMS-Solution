$path = 'E:\GitHub\SQLDBA-SSMS-Solution'

$files = Get-ChildItem -Path $path -Recurse -File

#$files | select * -First 1

# read content
$files_readable = $files | Where-Object {$_.Extension -in @('.md','.sql','.ps1','.xml','.txt')}
$files_noIssue = [System.Collections.ArrayList]@();
$files_Issue = [System.Collections.ArrayList]@();
foreach($file in $files_readable) {
    $fullName = $file.FullName;
    $fc = Get-Content -LiteralPath $fullName;
    
    if($fc -match "confidential") {
        Write-Host "Found => $fullName" -ForegroundColor Red -BackgroundColor White
        $fc | ForEach-Object {$_ -replace "confidential", 'contso'} | Set-Content -LiteralPath $fullName;
        $files_Issue.Add($fullName) | Out-Null;
        #break
        #$Matches
    } else {
        #Write-Host "$fullName" -ForegroundColor Green
        $files_noIssue.Add($fullName) | Out-Null;
    }
    #break;
}

#$files_noIssue | ogv -Title 'Files without any issue';
$files_Issue | ogv -Title 'Files with issue';