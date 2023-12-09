$sourceFolder = "/stale-storage/Study-Zone/SQL-Exercises"
$destinationFolder = "/stale-storage/Share/SQL-Exercises"
#New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item -Path $sourceFolder\* -Destination $destinationFolder -recurse -Force -Exclude "*.mp4" -WhatIf