param(
  [string]$DeviceId,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$scriptPath = Join-Path $PSScriptRoot "flutter_with_env.ps1"
& $scriptPath -Command run -AppEnv dev -DeviceId $DeviceId -ExtraArgs $ExtraArgs
exit $LASTEXITCODE
