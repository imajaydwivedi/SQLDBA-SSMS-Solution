$SQLServers = @('MyDbServer01','MyDbServer02','MyDbServer03','MyDbServer04')
$Users = @('Contso\SomeUser01','Contso\SomeUser02','Contso\SomeUser03')


foreach($Srv in $SQLServers)
{
    foreach($Usr in $Users)
    {
        $command = {
            param($User)
            Write-Output "$($env:COMPUTERNAME) => $User";
            net Localgroup Administrators $User /add     
        }
        Invoke-Command -ComputerName $Srv -ScriptBlock $command -Args $Usr;
    }
}