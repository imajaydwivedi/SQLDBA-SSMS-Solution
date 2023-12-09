# Find involved tables in Query using SQLPLan
$rawFile = "C:\Users\Ajay\Downloads\207-plan.sqlplan"

$rawFileContent = Get-Content $rawFile

[System.Collections.ArrayList]$tables = @()

foreach($line in $rawFileContent)
{
    cls
    if($line -match "Database=`"\[(?'Database'\w+)\]`"\s+Schema=`"\[(?'Schema'\w+)`]`"\s+Table=`"\[(?'Table'\w+)\]`"\s")
    {
        #$line
        #$Matches

        $obj = [PSCustomObject]@{
            Database = $Matches['Database']
            Schema = $Matches['Schema']
            Table = $Matches['Table']
            FullName = $Matches['Database']+'.'+$Matches['Schema']+'.'+$Matches['Table']
        }
        $tables.Add($obj)|Out-Null
    }
}

$tables | Select-Object * -Unique | ogv
$tables | Select-Object Database -Unique
