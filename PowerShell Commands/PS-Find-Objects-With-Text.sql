<# Find Objects with INDEX HINT 
    Can be used to search for any text in SQL Server objects
#>
$directory = 'D:\GitHub-Office\DBA-SRE\196_Databases'

$files = @()
$files += Get-ChildItem -Path $directory -Recurse -File

$filesWithIndexHint = @()
foreach($file in $files)
{
    #$filePath = 'D:\GitHub-Office\DBA-SRE\196_Databases\Regular-Expression-Test\test-file.sql'
    $filePath = $file.FullName
    $fileContent = Get-Content $filePath
    if($fileContent -match "with\s*\(\s*index") {
        $filesWithIndexHint += $file
    }
}

$filesWithIndexHint

$objectsWithIndexHint = @()
foreach($file in $filesWithIndexHint)
{
    $name = $file.BaseName
    $filePath = $file.FullName
    $fileDirectory = $file.Directory
    $fileDirectoryName = $file.DirectoryName

    $objName = $fileDirectoryName.Replace($directory,'').Replace($fileDirectory.Name,'').TrimStart('\').Replace('\','.')+'['+$name+']'
    $fileObj = New-Object -TypeName psobject -Property @{ObjectName = $objName; Path = $fileDirectoryName.Replace($directory,'')}
    $objectsWithIndexHint += $fileObj
}

