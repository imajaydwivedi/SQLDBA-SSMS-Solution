<#	01) Creating Efficient Collection, and adding Object  #>
[System.Collections.ArrayList]$Combined3 = @()
$files | ForEach-Object{
    $obj = [PSCustomObject]@{
        FileName  = $_.fullname
        LastWrite = $_.Lastwritetime
    }
    $Combined3.Add($obj)|Out-Null
}

<#	02) Creating Efficient Collection, and adding Object in OneLine (More Efficient) #>
[System.Collections.ArrayList]$Omega = @()
$files.ForEach({$obj = [PSCustomObject]@{ FileName  = $_.fullname; LastWrite = $_.Lastwritetime};$Omega.add($obj)|out-null})}

<#	03 - All various ways to work on Array Collection	#>
https://www.red-gate.com/simple-talk/sysadmin/powershell/powershell-one-liners-collections-hashtables-arrays-and-strings/

$BlitzIndex_Summary_Groups.ForEach({$obj = [PSCustomObject]@{ Finding  = $_.Values[0]; Database = $_.Values[1]; Count = $_.Count} $obj;})


<#	04) Creating Efficient Collection, and adding Query Result from Multiple servers  #>
..\PowerShell Commands\PowerShell-Efficient-Fetch-From-Multiple-Servers.sql

