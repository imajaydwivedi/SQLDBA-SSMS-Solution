function Retry-Command
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position=1, Mandatory=$false)]
        [int]$Maximum = 5,

        [Parameter(Position=2, Mandatory=$false)]
        [int]$Delay = 5000
    )

    Begin {
        $cnt = 0
    }

    Process {
        do {
            $cnt++
            try {
                $ScriptBlock.Invoke()
                return
            } catch {                
                $formatstring = "{0} : {1}`n{2}`n" +
                            "    + CategoryInfo          : {3}`n" +
                            "    + FullyQualifiedErrorId : {4}`n"
                $fields = $_.InvocationInfo.MyCommand.Name,
                            $_.ErrorDetails.Message,
                            $_.InvocationInfo.PositionMessage,
                            $_.CategoryInfo.ToString(),
                            $_.FullyQualifiedErrorId

                $returnMessage = $formatstring -f $fields;
                $returnMessage = "Retry-Command failed for ScriptBlock => `n$ScriptBlock`n" + $returnMessage;
                
                Start-Sleep -Milliseconds $Delay
            }
        } while ($cnt -lt $Maximum)

        # Throw an error after $Maximum unsuccessful invocations. Doesn't need
        # a condition, since the function returns upon successful invocation.
        throw $returnMessage
    }
<#
.SYNOPSIS
This function can be used to execute same code for specified number of times
.DESCRIPTION
This function helps to retry an action a number of times by executing same code inside try/catch.
.PARAMETER ScriptBlock
Scripblock to execute for multiple times
.PARAMETER Maximum
Number of retries to perform
.PARAMETER Delay
Time of pause between each retry
.EXAMPLE
Retry-Command -ScriptBlock {
    # do something
}
.EXAMPLE
Retry-Command -ScriptBlock {
    # do something
} -Maximum 10
.LINK
https://stackoverflow.com/a/45472343/4449743
#>
}