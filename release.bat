@echo off
REM PAX Release Script - Windows Batch Wrapper
REM 
REM Usage Examples:
REM   release.bat                              # Patch version
REM   release.bat -Patch                       # Patch version  
REM   release.bat -Minor                       # Minor version
REM   release.bat -Major                       # Major version
REM   release.bat -Minor -Message "New features added"  # Custom message
REM   release.bat -Help                        # Show help

setlocal enabledelayedexpansion

REM Check if PowerShell is available
where pwsh >nul 2>&1
if %ERRORLEVEL% == 0 (
    set PS_CMD=pwsh
) else (
    where powershell >nul 2>&1
    if !ERRORLEVEL! == 0 (
        set PS_CMD=powershell
    ) else (
        echo ERROR: Neither PowerShell 7 nor PowerShell 5.1 found!
        exit /b 1
    )
)

REM Pass all arguments to PowerShell script
!PS_CMD! -ExecutionPolicy Bypass -File "%~dp0release.ps1" %*