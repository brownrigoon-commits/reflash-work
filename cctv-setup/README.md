# cctv-setup — B창고 CCTV 녹화서버 구축 파일

이 폴더는 리플래시 **B창고 CCTV 녹화서버** 구축용 파일 모음입니다.
저장소의 웹앱(`index.html` 등)과 **섞이지 않도록 따로 관리**합니다.

## 파일

| 파일 | 설명 |
|---|---|
| `_작업지시서_클로드코드용.md` | 전체 작업 지시서. B창고 PC에서 실행하는 Claude Code가 읽고 따르는 문서. **먼저 이걸 읽으세요.** |
| `B_1_카메라찾기.ps1` | STEP 1 — 같은 망의 Tapo 카메라(RTSP 554 포트) 스캔. 관리자 권한 불필요. |
| `B_2_서버설치_D드라이브.ps1` | STEP 3 — MediaMTX 녹화서버 + Tailscale 설치, D드라이브 저장, 절전해제·방화벽·감시·용량관리 자동 설정. **관리자 권한 필요.** |

## B창고 PC에서 쓰는 법

작업지시서와 스크립트는 B창고 PC의 `C:\cctv-setup\` 폴더에 있어야 합니다.
이 저장소에서 내려받아 그 위치에 두면 됩니다. 예:

```powershell
# 예시: 이 폴더 파일을 C:\cctv-setup\ 로 복사한 뒤
Get-ChildItem C:\cctv-setup\*.ps1 | Unblock-File          # 브라우저 차단 해제
powershell -ExecutionPolicy Bypass -File C:\cctv-setup\B_1_카메라찾기.ps1   # STEP 1
```

자세한 순서(STEP 1~6)와 주의사항은 `_작업지시서_클로드코드용.md` 를 따르세요.

## 확정된 값 (요약)

- B PC IP `192.168.0.115` / 게이트웨이 `192.168.0.1` (TP-Link_3827)
- 카메라 Tapo 7대 · 계정 `Reflashcam` / `rfcam2026`
- 외부 카메라 1대 확정: `192.168.0.107` (B창고 외부1, C310)
- 녹화 저장: **D드라이브** (C드라이브는 여유 부족 — 사용 금지)
