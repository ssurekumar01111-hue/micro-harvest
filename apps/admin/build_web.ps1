# Load from .env file if it exists
if (Test-Path .env) {
    Get-Content .env | ForEach-Object {
        if ($_ -match "^[^#].*=.*") {
            $name, $value = $_.Split('=', 2)
            Set-Item -Path "env:$($name.Trim())" -Value $value.Trim()
        }
    }
} else {
    Write-Error ".env file not found! Create one based on .env.example"
    exit 1
}

flutter build web `
  --dart-define=FIREBASE_API_KEY=$env:FIREBASE_API_KEY `
  --dart-define=FIREBASE_APP_ID=$env:FIREBASE_APP_ID `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=$env:FIREBASE_MESSAGING_SENDER_ID `
  --dart-define=FIREBASE_PROJECT_ID=$env:FIREBASE_PROJECT_ID `
  --dart-define=FIREBASE_AUTH_DOMAIN=$env:FIREBASE_AUTH_DOMAIN `
  --dart-define=FIREBASE_STORAGE_BUCKET=$env:FIREBASE_STORAGE_BUCKET `
  --dart-define=FIREBASE_MEASUREMENT_ID=$env:FIREBASE_MEASUREMENT_ID

Write-Host "Build complete. Run: firebase deploy --only hosting"
