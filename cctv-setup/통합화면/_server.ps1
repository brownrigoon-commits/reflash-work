# ============================================================
#  리플래시 CCTV 통합화면 - 로컬 서버 (숨김 실행)
#  직접 실행하지 마세요. "리플래시 CCTV 보기.vbs" 를 쓰세요.
# ============================================================

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$port = 8099
$url  = "http://127.0.0.1:$port/console.html"

# 이미 서버가 켜져 있으면 브라우저만 열고 끝낸다 (중복 실행 방지)
$listener = $null
try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://127.0.0.1:$port/")
    $listener.Start()
} catch {
    Start-Process $url
    exit
}

Start-Process $url

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.ico'  = 'image/x-icon'
}

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.LocalPath).TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($rel)) { $rel = 'console.html' }

        $full = [System.IO.Path]::GetFullPath((Join-Path $root $rel))
        if (-not $full.StartsWith([System.IO.Path]::GetFullPath($root))) {
            $ctx.Response.StatusCode = 403
            $ctx.Response.Close()
            continue
        }

        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($full)
            $ext = [System.IO.Path]::GetExtension($full).ToLower()
            $ctx.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $ctx.Response.StatusCode = 404
        }
        $ctx.Response.Close()
    } catch {
        break
    }
}

try { $listener.Stop() } catch {}
