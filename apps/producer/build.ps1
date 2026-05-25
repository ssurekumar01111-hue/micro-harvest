# Build Producer APK using .env.json
flutter build apk --dart-define-from-file=.env.json
Write-Host "Producer APK built: build/app/outputs/flutter-apk/app-release.apk"
