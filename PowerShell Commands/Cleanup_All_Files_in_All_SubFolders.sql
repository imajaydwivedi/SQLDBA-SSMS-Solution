# Delete files older than 48 hours
$CleanUpTimeHours = 48
$CleanUpTimeMinutes = 5
$a = Get-ChildItem I:\Backups\CW | Where-Object {$_.Name -like '*BKS*'}
$filesRemoved = @();

try {
    if($a.Count -gt 0)
    {
    	foreach($x in $a)
        {
            $y = ((Get-Date) - $x.CreationTime);
            $y_Hours = ($y.Days * 24) + ($y.Hours);
            $y_Minutes = ($y.Days * 24) + ($y.Hours) + ($y.Minutes);
            
            #Folder
            if ($y_Hours -gt $CleanUpTimeHours -and $x.PsISContainer)
            {
                Write-Output "Removing folder '$($x.Name)' with its content";
                $files = Get-ChildItem $x.Fullname -Recurse | Where-Object {$_.PsISContainer -ne $True};
                $subFolders = Get-ChildItem $x.Fullname -Recurse | Where-Object {$_.PsISContainer};
                
                # If files are found, then delete them
                if($files) {
                    $filesNames = $files | Select-Object -ExpandProperty Name;
                    $files | Remove-Item;
                }
                # If sub-folders are found, then delete them
                if($subFolders) {
                    $subFolders | Remove-Item;
                }
                
                $filesRemoved += $filesNames;
                $x.Delete();
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