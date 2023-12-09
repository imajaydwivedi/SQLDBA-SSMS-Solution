Invoke-DbaDbShrink -SqlInstance 'TSQLPRD01' `
                    -Database YouTubeMusi,DBATunes `
                    -FileType Log `
                    -StepSize 2048MB