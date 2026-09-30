@echo off
setlocal EnableDelayedExpansion

title OfflineKit SHA256 Verification

set "BASE=%~dp0"
set "MANIFEST=%BASE%SHA256_MANIFEST.txt"
set "REPORT=%BASE%_meta\VERIFY_REPORT.txt"

if not exist "%BASE%_meta" mkdir "%BASE%_meta"

echo ============================================
echo        OFFLINEKIT SHA256 VERIFICATION
echo ============================================
echo.

if not exist "%MANIFEST%" (
    echo ERROR: SHA256_MANIFEST.txt not found!
    echo.
    pause
    exit /b 1
)

set /a TOTAL=0
set /a OK=0
set /a FAILED=0
set /a MISSING=0

(
echo ============================================
echo        OFFLINEKIT SHA256 VERIFICATION
echo ============================================
echo.
) > "%REPORT%"

for /f "usebackq tokens=1,*" %%A in ("%MANIFEST%") do (

    set "EXPECTED=%%A"
    set "FILE=%%B"

    rem Skip empty lines
    if not "!FILE!"=="" (

        set /a TOTAL+=1

        echo [!TOTAL!] !FILE!

        if not exist "%BASE%!FILE!" (

            echo        [MISSING]
            echo [!TOTAL!] !FILE! [MISSING] >> "%REPORT%"
            set /a MISSING+=1

        ) else (

            rem Calculate SHA256 using certutil
            for /f "tokens=1" %%H in ('certutil -hashfile "%BASE%!FILE!" SHA256 ^| findstr /R /V "hash CertUtil"') do (
                set "ACTUAL=%%H"
            )

            if /I "!EXPECTED!"=="!ACTUAL!" (

                echo        [OK]
                echo [!TOTAL!] !FILE! [OK] >> "%REPORT%"
                set /a OK+=1

            ) else (

                echo        [FAILED]
                echo        Expected: !EXPECTED!
                echo        Actual:   !ACTUAL!

                (
                    echo [!TOTAL!] !FILE! [FAILED]
                    echo        Expected: !EXPECTED!
                    echo        Actual:   !ACTUAL!
                ) >> "%REPORT%"

                set /a FAILED+=1
            )
        )

        echo.
    )
)

echo ============================================
echo TOTAL:   !TOTAL!
echo OK:      !OK!
echo FAILED:  !FAILED!
echo MISSING: !MISSING!
echo ============================================
echo.
echo Report:
echo %REPORT%
echo.

(
echo.
echo ============================================
echo TOTAL:   !TOTAL!
echo OK:      !OK!
echo FAILED:  !FAILED!
echo MISSING: !MISSING!
echo ============================================
) >> "%REPORT%"

pause