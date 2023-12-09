# Delete files older than 48 hours
$CleanUpTimeHours = 48
$CleanUpTimeMinutes = 5
$a = Get-ChildItem I:\Backups\CW\Logs
$filesRemoved = @();

$filesRemoved = $a | Where-Object {$_.CreationTime -lt (Get-Date).AddHours(-$CleanUpTimeHours) }

try {
    if($filesRemoved.Count -gt 0)
    {
        Write-Output "`r`nRemoving $($filesRemoved.Count) number of files. ";
    	$filesRemoved | Remove-Item;
    }
    else {
        Write-Output "No files to remove";
    }
	return 0; #success
}
catch {
    $formatstring = "{0} : {1}`n{2}`n" +
                "    + CategoryInfo          : {3}`n" +
                "    + FullyQualifiedErrorId : {4}`n"
    $fields = $_.InvocationInfo.MyCommand.Name,
              $_.ErrorDetails.Message,
              $_.InvocationInfo.PositionMessage,
              $_.CategoryInfo.ToString(),
              $_.FullyQualifiedErrorId

    $formatstring -f $fields
    Write-Output ($_.Exception.Message);
	return 1; #failure
}