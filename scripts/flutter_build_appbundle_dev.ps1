param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$scriptPath = Join-Path $PSScriptRoot "flutter_with_env.ps1"
& $scriptPath -Command build-appbundle -AppEnv dev -ExtraArgs $ExtraArgs
exit $LASTEXITCODE
