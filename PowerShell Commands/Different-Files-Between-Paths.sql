$p_tgt = 'C:\Users\adwivedi\Documents\WindowsPowerShell\Modules\SQLDBATools'
$srcServer = 'ourinventoryserver'
$p_src = 'C:\Program Files\WindowsPowerShell\Modules\SQLDBATools'

$tgt_files = Get-ChildItem $p_tgt -Recurse -File;
$src_files = Invoke-Command -ComputerName $srcServer -ScriptBlock { Get-ChildItem $Using:p_src -Recurse -File }

foreach($sf in $src_files) {
    if($sf.Name -notin ($tgt_files | select -ExpandProperty Name)) {
        $sf.Name
        #Copy-Item $sf.FullName -Destination $p_
    }
}