# Build Admin Web using .env.json and deploy
flutter build web --dart-define-from-file=.env.json
firebase deploy --only hosting
Write-Host "Admin panel deployed to https://micro-harvest.web.app"
