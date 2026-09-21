@echo off
:: IT Support Toolkit - Launcher
:: Automatically prompts for Administrator privileges if not elevated
setlocal

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [i] Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c \"\"%~dpnx0\"\"' -Verb RunAs"
    exit /b
)

title IT Administration Repair Toolkit
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0toolkit.ps1"
if %errorlevel% neq 0 (
    pause
)
