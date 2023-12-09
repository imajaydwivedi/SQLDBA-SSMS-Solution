$file = "$($env:TEMP)\Get-LinkedServer.html";
$CssStyleSheet = (Get-Module -Name SQLDBATools -ListAvailable).ModuleBase+"\HTML\"+$Global:SQLDBATools_CssStyleSheet;
if(Test-Path $file) {Remove-Item $file -Force -WarningAction SilentlyContinue;}

#$result = Get-LinkedServer -SqlInstance 'MyDbServerName\sql2017';

$frag1 = $result |
    ConvertTo-EnhancedHTMLFragment -DivCssID LinkedServerDiv `
                                   -DivCssClass LinkedServerClass `
                                   -TableCssID LinkedServerTable `
                                   -TableCssClass LinkedServerClass `
                                   -As Table `
                                   -Properties SqlInstance, LinkServer, ProductName, DataSource, ProviderName, User, Password,@{n='<input type="checkbox" name="ScriptOut" value="Show" checked> ScriptOut';e={$_.ScriptOut};css={'ScriptOut LargeText'}} `
                                   -EvenRowCssClass Even `
                                   -OddRowCssClass Odd `
                                   -MakeTableDynamic `
                                   -PreContent '<h2>MyDbServerName\sql2017</h2>' `
                                   -MakeHiddenSection `
                                   -PostContent "Retrieved $(Get-Date)" |
    Out-String


ConvertTo-EnhancedHTML  -HTMLFragments $frag1 `
                        -Title "LinkedServer" `
                        -PreContent "<h1>Linked Servers Details</h1>" `
                        -PostContent "<p></p>" `
                        -CssStyleSheet (Get-Content $CssStyleSheet) |
    Out-File $file
                        

&"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" --> $file
Start-Sleep -Seconds 3
#if(Test-Path $file) {Remove-Item $file -Force -WarningAction SilentlyContinue;}