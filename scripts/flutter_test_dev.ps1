param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$scriptPath = Join-Path $PSScriptRoot "flutter_with_env.ps1"
& $scriptPath -Command test -AppEnv dev -ExtraArgs $ExtraArgs
exit $LASTEXITCODE
