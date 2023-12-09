# Delete files older than 48 hours
$CleanUpTimeHours = 48
$CleanUpTimeMinutes = 5
$a = Get-ChildItem F:\dump\DiffBackups
$filesRemoved = @();

try {
    if($a.Count -gt 0)
    {
    	foreach($x in $a)
        {
            $y = ((Get-Date) - $x.CreationTime);
            $y_Hours = ($y.Days * 24) + ($y.Hours);
            $y_Minutes = ($y.Days * 24) + ($y.Hours) + ($y.Minutes);
            if ($y_Hours -gt $CleanUpTimeHours -and $x.PsISContainer -ne $True)
            #if ($y_Minutes -gt $CleanUpTimeMinutes -and $x.PsISContainer -ne $True)
                {	$x.Delete()
                    #Write-Host $x.Name;
                    #Write-Output $x.Name;
                    $filesRemoved += $x.Name;
    			}
        }
    }
    if($filesRemoved.Count -eq 0) {
        Write-Output "No files to remove";
    }
    else {
        Write-Output "`r`nBelow files were removed successfully:- ";
        Write-Output $filesRemoved;
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