# ============================================================
#  B창고 CCTV - 1단계 : 카메라 찾기
#  관리자 권한 필요 없음. PowerShell 창에 붙여넣고 Enter.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
if (-not $cfg) { Write-Host '[오류] 네트워크 연결을 찾을 수 없습니다. 와이파이/랜선 확인.' -ForegroundColor Red; return }

$myip    = $cfg.IPv4Address.IPAddress
$gateway = $cfg.IPv4DefaultGateway.NextHop
$prefix  = ($myip -split '\.')[0..2] -join '.'

Write-Host ''
Write-Host '=====  B창고 카메라 찾기  =====' -ForegroundColor Yellow
Write-Host ("   이 PC IP  : $myip")
Write-Host ("   공유기 IP : $gateway")
Write-Host ("   검색 대역 : $prefix.1 ~ $prefix.254")
Write-Host ''
Write-Host '검색 중... 약 40초 걸립니다. 창을 닫지 마세요.' -ForegroundColor Cyan

# --- 1) 대역 전체 핑 (ARP 테이블 채우기) ---
$tasks = @()
foreach ($i in 1..254) {
    $p = New-Object System.Net.NetworkInformation.Ping
    $tasks += $p.SendPingAsync("$prefix.$i", 800)
}
Start-Sleep -Seconds 4

# --- 2) RTSP(554) 포트 동시 스캔 ---
$targets = 1..254 | ForEach-Object { "$prefix.$_" }
$sock = @{}
foreach ($ip in $targets) {
    $tc = New-Object System.Net.Sockets.TcpClient
    $sock[$ip] = [pscustomobject]@{ Client = $tc; Handle = $tc.BeginConnect($ip, 554, $null, $null) }
}
Start-Sleep -Seconds 4

# --- 3) ARP 테이블에서 MAC 주소 수집 ---
$arp = @{}
(arp -a) -split "`r?`n" | ForEach-Object {
    if ($_ -match '^\s*(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F\-]{17})') { $arp[$matches[1]] = $matches[2].ToUpper() }
}

$found = @()
foreach ($ip in $targets) {
    $o = $sock[$ip]
    if ($o.Client.Connected) {
        $mac = '-'
        if ($arp.ContainsKey($ip)) { $mac = $arp[$ip] }
        $found += [pscustomobject]@{ IP = $ip; MAC = $mac; '카메라이름' = '(Tapo앱에서 확인해 적기)' }
    }
    try { $o.Client.Close() } catch {}
}

Write-Host ''
if ($found.Count -eq 0) {
    Write-Host '[결과] 카메라를 찾지 못했습니다.' -ForegroundColor Red
    Write-Host ''
    Write-Host '확인할 것 3가지:' -ForegroundColor Yellow
    Write-Host '  1. Tapo 앱에서 [카메라 계정] 을 만들고 "활성" 스위치를 켰는지'
    Write-Host '  2. Tapo Care(무료체험 포함)를 껐는지'
    Write-Host '  3. 카메라와 이 PC가 같은 와이파이인지'
    Write-Host ("     - 이 PC는 $prefix.x 대역입니다. Tapo앱 장치정보의 카메라 IP 앞 3자리가 같아야 합니다.") -ForegroundColor Cyan
    Write-Host '  → 위를 고친 뒤 카메라 전원을 뽑았다 꽂고, 2분 후 이 스크립트를 다시 실행하세요.'
} else {
    Write-Host ("[결과] 카메라 후보 " + $found.Count + "대 발견 (RTSP 554 열림)") -ForegroundColor Green
    Write-Host ''
    $found | Format-Table -AutoSize
}

$out = "$env:USERPROFILE\Desktop\B창고_카메라목록.txt"
$body = @()
$body += "B창고 카메라 검색 결과  ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
$body += "이 PC IP : $myip   /  공유기 : $gateway"
$body += "----------------------------------------"
if ($found.Count -eq 0) { $body += "발견된 카메라 없음" }
else { foreach ($f in $found) { $body += ("{0}   MAC {1}   이름: " -f $f.IP, $f.MAC) } }
Set-Content -Path $out -Value $body -Encoding UTF8

Write-Host ''
Write-Host ("결과가 바탕화면에 저장되었습니다 →  " + $out) -ForegroundColor Yellow
Write-Host '이 화면을 캡처하거나 위 파일을 저에게 보내주세요.' -ForegroundColor Yellow
Write-Host ''
