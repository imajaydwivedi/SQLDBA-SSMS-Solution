[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [int]$LoanAmount = 40000,
    [Parameter(Mandatory=$false)]
    [float]$InterestRate = 15,
    [Parameter(Mandatory=$false)]
    [int]$Months = 12,
    [Parameter(Mandatory=$false)]
    [float]$ProcessingFeePercent = 3
)

cls
"Loan amount => $LoanAmount" | Write-Host -ForegroundColor Cyan
"Interest Rate (%) => $InterestRate" | Write-Host -ForegroundColor Cyan
"Tenure (Months) => $Months" | Write-Host -ForegroundColor Cyan
"Processing Rate (%) => $ProcessingFeePercent" | Write-Host -ForegroundColor Cyan

$processingAmount = $ProcessingFeePercent * $LoanAmount / 100.0
"`nProcessing Rate (%) => $ProcessingFeePercent" | Write-Host -ForegroundColor Green




