# https://github.com/proxb/PoshRSJob
Import-Module PoshRSJob;
$Test = 'test'
$Something = 1..10
1..5|start-rsjob -Name {$_} -ScriptBlock {
        [pscustomobject]@{
            Result=($_*2)
            Test=$Using:Test
            Something=$Using:Something
        }
}            
Get-RSjob | Receive-RSJob




# This shows the streaming aspect with Wait-RSJob
1..10|Start-RSJob {
    if (1 -BAND $_){
        "First ($_)"
    }Else{
        Start-sleep -seconds 2
        "Last ($_)"
    }
}|Wait-RSJob|Receive-RSJob|ForEach{"I am $($_)"}