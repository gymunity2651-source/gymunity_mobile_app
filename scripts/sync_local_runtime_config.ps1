param(
  [string]$EnvFile = ".env",
  [string]$OutputFile = "assets/config/local_env.json"
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = if ([System.IO.Path]::IsPathRooted($EnvFile)) {
  $EnvFile
} else {
  Join-Path $projectRoot $EnvFile
}

$outputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
  $OutputFile
} else {
  Join-Path $projectRoot $OutputFile
}

if (-not (Test-Path $envPath)) {
  throw "Env file not found at $envPath"
}

$allowedKeys = @(
  "APP_ENV",
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "AUTH_REDIRECT_SCHEME",
  "AUTH_REDIRECT_HOST",
  "PRIVACY_POLICY_URL",
  "TERMS_OF_SERVICE_URL",
  "SUPPORT_URL",
  "SUPPORT_EMAIL",
  "SUPPORT_EMAIL_SUBJECT",
  "REVIEWER_LOGIN_HELP_URL",
  "ENABLE_COACH_ROLE",
  "ENABLE_SELLER_ROLE",
  "ENABLE_APPLE_SIGN_IN",
  "ENABLE_STORE_PURCHASES",
  "ENABLE_COACH_SUBSCRIPTIONS",
  "ENABLE_AI_PREMIUM",
  "APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID",
  "APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID",
  "GOOGLE_AI_PREMIUM_SUBSCRIPTION_ID",
  "GOOGLE_AI_PREMIUM_MONTHLY_BASE_PLAN_ID",
  "GOOGLE_AI_PREMIUM_ANNUAL_BASE_PLAN_ID"
)

$values = [ordered]@{}
Get-Content $envPath | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith("#")) {
    return
  }

  $parts = $line.Split("=", 2)
  if ($parts.Count -ne 2) {
    return
  }

  $key = $parts[0].Trim()
  $value = $parts[1].Trim()
  if ($key -and $allowedKeys -contains $key) {
    $values[$key] = $value
  }
}

if (-not $values.Contains("APP_ENV")) {
  $values["APP_ENV"] = "dev"
}

if (-not $values.Contains("AUTH_REDIRECT_SCHEME")) {
  $values["AUTH_REDIRECT_SCHEME"] = "gymunity"
}

if (-not $values.Contains("AUTH_REDIRECT_HOST")) {
  $values["AUTH_REDIRECT_HOST"] = "auth-callback"
}

$outputDir = Split-Path -Parent $outputPath
if (-not (Test-Path $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$values | ConvertTo-Json | Set-Content -Path $outputPath -Encoding UTF8

