# 리플래시 CCTV 서버 종료
$found = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
         Where-Object { $_.CommandLine -like '*_server.ps1*' }
if ($found) {
    $found | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    Write-Host '  CCTV 화면 서버를 껐습니다.' -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host '  실행 중인 CCTV 서버가 없습니다.' -ForegroundColor Yellow
}
Write-Host ''
Start-Sleep -Seconds 2
