' Reflash CCTV - stop the local server
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")
here = fso.GetParentFolderName(WScript.ScriptFullName)
sh.CurrentDirectory = here
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & here & "\_stop.ps1""", 0, True
MsgBox "CCTV 화면 서버를 껐습니다.", 64, "리플래시 CCTV"
