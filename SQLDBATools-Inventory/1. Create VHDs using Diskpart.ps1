$machinePath = 'E:\Virtual_Machines\VHDs\';
#$machines = @('DC','SQL-A','SQL-B','SQL-C','SQL-D','SQL-E','SQL-F','SQL-G');
$machines = @('DC');
$files = @('C_Drive.vhd','D_Drive.vhd','E_Drive.vhd','F_Drive.vhd','G_Drive.vhd','SQL_Data.vhd','SQL_Log.vhd','SQL_TempDb.vhd','SQL_SysDbs.vhd','SQL_Backup.vhd');
$files_20gb = @('SQL_Log.vhd','SQL_TempDb.vhd','SQL_SysDbs.vhd');
$vhdStatements = '';

foreach($vm in $machines)
{
    $VmVHDStatements = @"

REM *************************************************************
REM Create VHDs for $vm
REM *************************************************************
if not exist `"$($machinePath)$($vm)`" mkdir `"$($machinePath)$($vm)`"
"@;
    
    foreach($fl in $files)
    {
        if($files_20gb -contains $fl)
        {
            $vhdStmt = "`r`ncreate vdisk file=$($machinePath)$($vm)\$($fl) maximum=20480 type=expandable";
        }
        else
        {
            $vhdStmt = "`r`ncreate vdisk file=$($machinePath)$($vm)\$($fl) maximum=51200 type=expandable";
        }
        $VmVHDStatements = $VmVHDStatements + $vhdStmt;
    }
    $vhdStatements = $vhdStatements + $VmVHDStatements;
}

$vhdStatements | Out-File -FilePath c:\temp\VHD_Creation.txt
notepad c:\temp\VHD_Creation.txt
