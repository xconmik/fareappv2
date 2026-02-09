Param(
  [string]$Tag = $(Get-Date -Format "yyyy.MM.dd.HHmm")
)

$ErrorActionPreference = "Stop"

if (-not $env:GITHUB_TOKEN) {
  Write-Error "GITHUB_TOKEN is not set. Set it to a GitHub token with repo access."
}

$repo = "xconmik/fareappv2"
$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
$tagName = "v$Tag"

Write-Host "Building APK..."
flutter build apk

if (-not (Test-Path $apkPath)) {
  Write-Error "APK not found at $apkPath"
}

$headers = @{ Authorization = "token $env:GITHUB_TOKEN"; "User-Agent" = "release-uploader" }
$body = @{ tag_name = $tagName; name = $tagName; draft = $false; prerelease = $false } | ConvertTo-Json

Write-Host "Creating GitHub release $tagName..."
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Method Post -Headers $headers -Body $body
$uploadUrl = $release.upload_url -replace "\{\?name,label\}", "?name=app-release.apk"

Write-Host "Uploading APK..."
Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headers -ContentType "application/vnd.android.package-archive" -InFile $apkPath

Write-Host "Release created: $($release.html_url)"
Write-Host "Download: https://github.com/$repo/releases/download/$tagName/app-release.apk"
