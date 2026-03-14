param(
  [ValidateSet("run", "build-apk", "build-appbundle", "test")]
  [string]$Command = "run",
  [string]$DeviceId,
  [string]$EnvFile = ".env",
  [string]$AppEnv = "dev",
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = if ([System.IO.Path]::IsPathRooted($EnvFile)) {
  $EnvFile
} else {
  Join-Path $projectRoot $EnvFile
}

$androidStudioJbr = "C:\Program Files\Android\Android Studio\jbr"
$javaExe = if ($env:JAVA_HOME) {
  Join-Path $env:JAVA_HOME "bin\java.exe"
} else {
  $null
}

if (-not $javaExe -or -not (Test-Path $javaExe)) {
  $fallbackJavaExe = Join-Path $androidStudioJbr "bin\java.exe"
  if (Test-Path $fallbackJavaExe) {
    $env:JAVA_HOME = $androidStudioJbr
    $javaBin = Join-Path $androidStudioJbr "bin"
    $pathEntries = $env:Path -split ";"
    if (-not ($pathEntries -contains $javaBin)) {
      $env:Path = "$javaBin;$env:Path"
    }
  }
}

if (-not (Test-Path $envPath)) {
  throw "Env file not found at $envPath"
}

$syncScript = Join-Path $PSScriptRoot "sync_local_runtime_config.ps1"
& $syncScript -EnvFile $envPath
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$allowedKeys = @(
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

$values = @{}
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

if (-not $values.ContainsKey("SUPABASE_URL") -or -not $values["SUPABASE_URL"]) {
  throw "SUPABASE_URL is missing in $envPath"
}

if (-not $values.ContainsKey("SUPABASE_ANON_KEY") -or -not $values["SUPABASE_ANON_KEY"]) {
  throw "SUPABASE_ANON_KEY is missing in $envPath"
}

$flutterArgs = @()
switch ($Command) {
  "run" {
    $flutterArgs += @("run")
    if ($DeviceId) {
      $flutterArgs += @("-d", $DeviceId)
    }
  }
  "build-apk" {
    $flutterArgs += @("build", "apk")
  }
  "build-appbundle" {
    $flutterArgs += @("build", "appbundle")
  }
  "test" {
    $flutterArgs += @("test")
  }
}

$flutterArgs += "--dart-define=APP_ENV=$AppEnv"

foreach ($key in $allowedKeys) {
  if ($values.ContainsKey($key) -and $values[$key]) {
    $flutterArgs += "--dart-define=$key=$($values[$key])"
  }
}

if ($ExtraArgs) {
  $flutterArgs += $ExtraArgs
}

& flutter @flutterArgs
exit $LASTEXITCODE

