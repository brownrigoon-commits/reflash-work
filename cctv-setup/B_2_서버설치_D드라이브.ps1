# ============================================================
#  B창고 CCTV 녹화서버 설치  (v2 · D드라이브 저장 고정판)
#  ★ 반드시 [관리자 권한] PowerShell 에서 실행하세요.
#  하는 일 : MediaMTX(녹화서버) + Tailscale(원격접속) 설치,
#            절전해제, 방화벽, 5분 감시, D드라이브 용량 자동관리
# ============================================================

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host ''
Write-Host '=====  B창고 CCTV 녹화서버 설치 (v2)  =====' -ForegroundColor Yellow

# ---------- 관리자 권한 확인 ----------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ''
    Write-Host '[중지] 관리자 권한이 아닙니다.' -ForegroundColor Red
    Write-Host '  시작버튼 우클릭 → "Windows PowerShell(관리자)" 로 연 뒤 다시 실행해 주세요.' -ForegroundColor Yellow
    return
}

# ---------- [0] 녹화 저장 위치 : D 드라이브 고정 ----------
$recDrive = 'D:'
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'"
if (-not $disk) {
    Write-Host '[중지] D 드라이브를 찾을 수 없습니다. 연결 상태를 확인해 주세요.' -ForegroundColor Red
    return
}
$freeGB  = [math]::Round($disk.FreeSpace / 1GB)
$totalGB = [math]::Round($disk.Size / 1GB)
$recPath  = 'D:\cctv\recordings'
$recPathY = 'D:/cctv/recordings'

New-Item -ItemType Directory -Force -Path 'C:\cctv\mediamtx', $recPath | Out-Null
try { Set-Content -Path 'D:\cctv\_write_test.tmp' -Value 'ok' -ErrorAction Stop; Remove-Item 'D:\cctv\_write_test.tmp' -Force }
catch { Write-Host '[중지] D 드라이브에 쓰기 권한이 없습니다.' -ForegroundColor Red; return }

Write-Host ("[0] 녹화 저장 위치 : $recPath   (D드라이브 ${freeGB}GB / ${totalGB}GB 여유)") -ForegroundColor Cyan

# ---------- [1] MediaMTX 다운로드 ----------
Write-Host '[1] MediaMTX 녹화서버 다운로드 중...'
try {
    $rel   = Invoke-RestMethod 'https://api.github.com/repos/bluenviron/mediamtx/releases/latest' -UseBasicParsing
    $asset = $rel.assets | Where-Object { $_.name -like '*windows_amd64.zip' } | Select-Object -First 1
    Invoke-WebRequest $asset.browser_download_url -OutFile 'C:\cctv\mediamtx\m.zip' -UseBasicParsing
    Expand-Archive 'C:\cctv\mediamtx\m.zip' -DestinationPath 'C:\cctv\mediamtx' -Force
    Remove-Item 'C:\cctv\mediamtx\m.zip' -Force
    Write-Host ('    설치 완료 : ' + $rel.tag_name) -ForegroundColor Green
} catch {
    Write-Host '    [실패] 다운로드 실패. 인터넷 연결 확인 후 다시 실행하세요.' -ForegroundColor Red
    return
}

# ---------- [2] Tailscale 설치 ----------
$ts = 'C:\Program Files\Tailscale\tailscale.exe'
if (-not (Test-Path $ts)) {
    Write-Host '[2] Tailscale(원격접속) 설치 중...'
    Invoke-WebRequest 'https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi' -OutFile "$env:TEMP\ts.msi" -UseBasicParsing
    Start-Process msiexec -ArgumentList '/i', "$env:TEMP\ts.msi", '/quiet', '/norestart' -Wait
    Start-Sleep -Seconds 6
} else {
    Write-Host '[2] Tailscale 이미 설치되어 있음'
}

# ---------- [3] Tailscale 로그인 ----------
Write-Host ''
Write-Host '[3] Tailscale 로그인' -ForegroundColor Yellow
Write-Host '    ★ 잠시 후 브라우저가 열립니다.' -ForegroundColor Yellow
Write-Host '    ★ 반드시  brown.rigoon@gmail.com  구글 계정으로 로그인하세요.' -ForegroundColor Yellow
Write-Host '      (A창고와 같은 계정이어야 한 화면에서 같이 보입니다)'
Start-Process $ts -ArgumentList 'up', '--unattended' -WindowStyle Hidden
$opened = $false
$tsip   = ''
for ($i = 0; $i -lt 72; $i++) {
    $s = (& $ts status 2>&1 | Out-String)
    $m2 = [regex]::Match($s, '(?m)^100\.\d+\.\d+\.\d+')
    if ($m2.Success) { $tsip = $m2.Value; break }
    if (-not $opened) {
        $m = [regex]::Match($s, 'https://login\.tailscale\.com/\S+')
        if ($m.Success) { Start-Process $m.Value; $opened = $true }
    }
    Start-Sleep -Seconds 5
}
if ($tsip) { Write-Host ("    연결 성공!  B PC Tailscale IP = $tsip") -ForegroundColor Green }
else       { Write-Host '    로그인 미완료 - 설치는 계속됩니다. 나중에 tailscale up 재실행.' -ForegroundColor Red }

# ---------- [4] mediamtx.yml 뼈대 생성 ----------
$hostLine = "# webrtcAdditionalHosts: [ '나중에_Tailscale_IP_기입' ]"
if ($tsip) { $hostLine = "webrtcAdditionalHosts: [ '$tsip' ]" }

$yml = @"
# B창고 녹화서버 설정 - 카메라는 아래 paths 아래에 추가합니다
logLevel: info
logDestinations: [stdout, file]
logFile: D:/cctv/mediamtx.log
api: yes
apiAddress: 127.0.0.1:9997
playback: yes
playbackAddress: :9996
playbackAllowOrigin: '*'
hls: yes
hlsAddress: :8888
hlsVariant: lowLatency
hlsAllowOrigin: '*'
webrtc: yes
webrtcAddress: :8889
webrtcAllowOrigin: '*'
$hostLine

pathDefaults:
  rtspTransport: tcp
  record: no
  recordPath: $recPathY/%path/%Y-%m-%d_%H-%M-%S-%f
  recordFormat: fmp4
  recordPartDuration: 1s
  recordSegmentDuration: 1h
  recordDeleteAfter: 720h        # 30일 상한. 실제 보존일수는 용량지킴이가 D드라이브에 맞춰 자동 조절

paths:
  # 카메라 등록 예시 - 실제 IP로 바꿔 사용
  # b01:
  #   source: rtsp://Reflashcam:rfcam2026@192.168.0.101:554/stream1
  #   record: yes
  # b01sub:
  #   source: rtsp://Reflashcam:rfcam2026@192.168.0.101:554/stream2
"@

if (Test-Path 'C:\cctv\mediamtx\mediamtx.yml') {
    Copy-Item 'C:\cctv\mediamtx\mediamtx.yml' ('C:\cctv\mediamtx\mediamtx.yml.bak_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) -Force
    Write-Host '[4] 기존 mediamtx.yml 백업 후 유지' -ForegroundColor Green
} else {
    Set-Content 'C:\cctv\mediamtx\mediamtx.yml' $yml -Encoding UTF8
    Write-Host '[4] mediamtx.yml 뼈대 생성 완료' -ForegroundColor Green
}

# ---------- [5] 절전 해제 (24시간 녹화) ----------
Write-Host '[5] 절전 모드 해제...'
powercfg /change standby-timeout-ac 0    | Out-Null
powercfg /change hibernate-timeout-ac 0  | Out-Null
powercfg /change disk-timeout-ac 0       | Out-Null
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
powercfg /SetActive SCHEME_CURRENT       | Out-Null

# ---------- [6] 방화벽 허용 ----------
Write-Host '[6] 방화벽 허용...'
try {
    Get-NetFirewallRule -DisplayName '리플래시 CCTV 서버(B)' -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName '리플래시 CCTV 서버(B)' -Direction Inbound -Program 'C:\cctv\mediamtx\mediamtx.exe' -Action Allow -Profile Any -ErrorAction Stop | Out-Null
} catch {}

# ---------- [7] 감시견 + 용량관리 ----------
$wd = @'
$p = Get-Process -Name mediamtx -ErrorAction SilentlyContinue
if (-not $p) {
    Start-Process -FilePath "C:\cctv\mediamtx\mediamtx.exe" -WorkingDirectory "C:\cctv\mediamtx" -WindowStyle Hidden
    Add-Content -Path "D:\cctv\watchdog.log" -Value ((Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  MediaMTX 재시작함")
}
'@
Set-Content 'C:\cctv\watchdog.ps1' $wd -Encoding UTF8

$guard = @'
# D드라이브 여유공간 지킴이 : 여유가 기준 미만이면 오래된 녹화파일부터 삭제
$MinFreeGB = 80
$Root = "D:\cctv\recordings"
if (-not (Test-Path $Root)) { return }
$d = Get-PSDrive -Name D -ErrorAction SilentlyContinue
if (-not $d) { return }
if (($d.Free / 1GB) -ge $MinFreeGB) { return }
$deleted = 0
$files = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime
foreach ($f in $files) {
    $d = Get-PSDrive -Name D -ErrorAction SilentlyContinue
    if (($d.Free / 1GB) -ge $MinFreeGB) { break }
    Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
    $deleted++
}
if ($deleted -gt 0) {
    Add-Content -Path "D:\cctv\diskguard.log" -Value ((Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  여유공간 확보: 오래된 파일 $deleted 개 삭제")
}
'@
Set-Content 'C:\cctv\diskguard.ps1' $guard -Encoding UTF8

$psExe = 'powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File '
schtasks /create /f /tn "리플래시 CCTV 녹화서버(B)"        /tr "$psExe`C:\cctv\watchdog.ps1"  /sc minute /mo 5 /ru SYSTEM /rl HIGHEST | Out-Null
schtasks /create /f /tn "리플래시 CCTV 녹화서버(B) 부팅시작" /tr "$psExe`C:\cctv\watchdog.ps1"  /sc onstart      /ru SYSTEM /rl HIGHEST | Out-Null
schtasks /create /f /tn "리플래시 CCTV 용량관리(B)"        /tr "$psExe`C:\cctv\diskguard.ps1" /sc hourly       /ru SYSTEM /rl HIGHEST | Out-Null
Write-Host '[7] 자동감시(5분) · 부팅시작 · 용량관리(1시간) 등록 완료' -ForegroundColor Green

# ---------- [8] 서버 시작 ----------
Get-Process -Name mediamtx -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process -FilePath 'C:\cctv\mediamtx\mediamtx.exe' -WorkingDirectory 'C:\cctv\mediamtx' -WindowStyle Hidden
Start-Sleep -Seconds 3
$alive = Get-Process -Name mediamtx -ErrorAction SilentlyContinue
if ($alive) { Write-Host '[8] 녹화서버 실행 중' -ForegroundColor Green }
else        { Write-Host '[8] 녹화서버 시작 실패 - D:\cctv\mediamtx.log 확인' -ForegroundColor Red }

# ---------- 결과 요약 ----------
$info = @()
$info += '===== B창고 CCTV 설치 결과 ====='
$info += "설치일시        : $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$info += "B PC Tailscale IP : $tsip"
$info += "녹화 저장 위치   : $recPath  (여유 ${freeGB}GB)"
$info += "설정 파일        : C:\cctv\mediamtx\mediamtx.yml"
$info += '다음 할 일       : 카메라를 mediamtx.yml 에 등록'
$outFile = "$env:USERPROFILE\Desktop\B창고_설치결과.txt"
Set-Content -Path $outFile -Value $info -Encoding UTF8

Write-Host ''
Write-Host '==========  설치 완료  ==========' -ForegroundColor Green
Write-Host ("  B PC Tailscale IP : $tsip") -ForegroundColor Cyan
Write-Host ("  녹화 저장 위치     : $recPath") -ForegroundColor Cyan
Write-Host ("  결과 파일          : $outFile") -ForegroundColor Cyan
Write-Host ''
Write-Host '  위 내용을 저에게 보내주시면 카메라 등록을 이어서 진행합니다.' -ForegroundColor Yellow
Write-Host ''
