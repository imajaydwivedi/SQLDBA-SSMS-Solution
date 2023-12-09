$oldRepo = "D:\GitHub-Personal\SQLMonitor-old"
$newRepo = "D:\GitHub-Personal\SQLMonitor"
$extensionsToCopy = @('.ssmssqlproj')

$oldRepoChildFolders = Get-ChildItem -Path $oldRepo -Directory -Recurse
$oldRepoChildFiles = Get-ChildItem -Path $oldRepo -File -Recurse | ? {$_.Extension -in $extensionsToCopy}


# Create missing folders
foreach($fldr in $oldRepoChildFolders) {
    $folderName = $fldr.Name
    $fullPath = $fldr.FullName
    $newFullPath = $fullPath.Replace($oldRepo,$newRepo)

    "Working on folder '$folderName'.."
    if(-not (Test-Path $newFullPath)) {
        New-Item -Path $newFullPath -ItemType Directory | Out-Null
    }
}

# copy missing files of specific extensions
foreach($file in $oldRepoChildFiles) {
    $fileName = $file.Name
    $fullPath = $file.FullName
    $newDirectory = $file.DirectoryName.Replace($oldRepo,$newRepo)


    "Working on file '$fileName'.."
    if(-not (Test-Path "$newDirectory\$fileName")) {
        Copy-Item $fullPath -Destination $newDirectory
    }
}