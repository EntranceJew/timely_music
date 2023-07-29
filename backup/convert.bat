@echo off & setlocal
FOR /r %%i in (*.mp3) DO (
	ffmpeg -i "%%~fi" -acodec pcm_s16le -ac 1 -ar 44100 "%%~dpni.wav"
	del /f /q "%%~fi"
)