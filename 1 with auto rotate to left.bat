@echo off
setlocal enabledelayedexpansion
title PC-to-PSP Bulletproof Smart Converter (CRF 16)

echo =============================================
echo    PC-TO-PSP SMART CONVERTER (CRF 16)       
echo    WITH REVERSE ROTATE ^& EVEN-PIXEL REPAIR 
echo =============================================

:: Gumawa ng mga kailangang subfolders sa kung saan nakalagay ang .bat file
mkdir "PSP_Output" 2>nul
mkdir "PSP_fin" 2>nul

:: Mag-scan ng lahat ng .mp4 sa kasalukuyang folder
for %%F in (*.mp4) do (
    echo Processing: %%F...

    :: 1. Alamin ang Width at Height gamit ang ffprobe
    for /f "tokens=*" %%A in ('ffprobe -v error -select_streams v:0 -show_entries stream^=width -of default^=nw^=1:nk^=1 "%%F"') do set WIDTH=%%A
    for /f "tokens=*" %%A in ('ffprobe -v error -select_streams v:0 -show_entries stream^=height -of default^=nw^=1:nk^=1 "%%F"') do set HEIGHT=%%A
    
    :: 2. Alamin ang Rotation tag kung mayroon
    set ROTATION=0
    for /f "tokens=*" %%A in ('ffprobe -v error -select_streams v:0 -show_entries stream_tags^=rotate -of default^=nw^=1:nk^=1 "%%F" 2^>nul') do set ROTATION=%%A

    :: 3. Alamin ang kabuuang Duration para sa math ng thumbnail
    set DURATION=0
    for /f "tokens=*" %%A in ('ffprobe -v error -show_entries format^=duration -of default^=nw^=1:nk^=1 "%%F"') do set DURATION=%%A

    :: Math para sa 1/4 (quarter) ng video gamit ang powershell dahil bawal ang decimal sa pure batch math
    for /f "tokens=*" %%A in ('powershell -Command "[math]::Round(!DURATION! / 4, 2)"') do set THUMB_TIME=%%A
    echo -^> Total Duration: !DURATION!s ^| Thumbnail target: !THUMB_TIME!s

    :: Default Filters para sa normal na Landscape (may even-pixel padding protection para sa Telegram)
    set "VF=scale='trunc(min(480,iw*272/ih)/2)*2':'trunc(min(272,ih*480/iw)/2)*2',format=yuv420p"
    set "TF=scale='trunc(min(160,iw*120/ih)/2)*2':'trunc(min(120,ih*480/iw)/2)*2'"

    :: 4. Smart Logic: Kung TikTok o Patayo ang video, iikot pakaliwa (transpose=2)
    if !HEIGHT! GTR !WIDTH! set ROTATE_NOW=1
    if "!ROTATION!"=="90" set ROTATE_NOW=1
    if "!ROTATION!"=="270" set ROTATE_NOW=1

    if defined ROTATE_NOW (
        echo -^> TikTok format na-detect! Awtomatikong ipipikit sa kabilang panig...
        set "VF=transpose=2,scale='trunc(min(480,iw*272/ih)/2)*2':'trunc(min(480,ih*272/iw)/2)*2',format=yuv420p"
        set "TF=transpose=2,scale='trunc(min(160,iw*120/ih)/2)*2':'trunc(min(120,ih*480/iw)/2)*2'"
        set "ROTATE_NOW="
    )

    :: 5. Patakbuhin ang main video conversion (CRF 16, -aspect 16:9)
    ffmpeg -i "%%F" -vf "!VF!" -aspect 16:9 -c:v libx264 -profile:v baseline -level 3.0 -x264opts nocabac:bframes=0:ref=1 -crf 20 -c:a aac -b:a 128k -ar 48000 -movflags +faststart "PSP_Output\%%~nF_psp.mp4" -y

    :: 6. Paggawa ng thumbnail (.thm)
    ffmpeg -i "%%F" -ss !THUMB_TIME! -vf "!TF!" -vframes 1 -f image2 "PSP_Output\%%~nF_psp.thm" -y

    :: 7. KUNG WALANG ERROR: I-move ang orihinal na file sa PSP_fin
    if !errorlevel! equ 0 (
        echo -^> Conversion successful! Inililipat ang orihinal na file sa PSP_fin...
        move "%%F" "PSP_fin\" >nul
    ) else (
        echo -^> [ERROR] May problema sa pag-convert. Hindi muna ito ililipat.
    )
    echo ---------------------------------------------
)

echo =============================================
echo    TAPOS NA LAHAT! Na-move na sa PSP_fin.    
echo =============================================
pause
