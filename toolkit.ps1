# IT Administration Repair and Troubleshooting Toolkit
# Compatible with PowerShell 5.1 and PowerShell 7+ on Windows 10/11/Server
# Public Repository: https://github.com/iN4sser/IT-Support-Tools

$ErrorActionPreference = "Continue"

# -------------------------------------------------------------------------
# 1. ELEVATION CHECK AND AUTO-RELAUNCH
# -------------------------------------------------------------------------
function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Host "[!] Administrator rights are required for repair operations." -ForegroundColor Yellow
    Write-Host "[*] Attempting to elevate..." -ForegroundColor Cyan
    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { [ScriptBlock]::Create((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/iN4sser/IT-Support-Tools/main/toolkit.ps1?$timestamp')).Invoke() }`""
        if ($MyInvocation.MyCommand.Path) {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        }
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
        exit
    }
    catch {
        Write-Host "[-] Failed to auto-elevate: $_" -ForegroundColor Red
        Write-Host "Please right-click PowerShell and choose 'Run as Administrator'." -ForegroundColor White
        Pause
        exit 1
    }
}

# -------------------------------------------------------------------------
# 2. CONSOLE SETUP & HELPER FUNCTIONS
# -------------------------------------------------------------------------
function Set-ConsoleTheme {
    try {
        $host.UI.RawUI.WindowTitle = "IT Administration Repair Toolkit"
        [Console]::ForegroundColor = [ConsoleColor]::Green
    }
    catch {
        # Fallback if host does not support direct window adjustments
    }
}

function Write-ToolkitHeader {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor DarkGreen
    Write-Host "                        IT ADMINISTRATION REPAIR TOOLKIT                        " -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor DarkGreen
    Write-Host ""
}

function Show-ActionHeader([string]$Title) {
    Clear-Host
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " TASK: $Title" -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Wait-UserPrompt {
    Write-Host ""
    Write-Host "Press any key to return to menu..." -ForegroundColor DarkGray
    [void][System.Console]::ReadKey($true)
}

function Confirm-Action([string]$Message) {
    Write-Host "$Message (y/N): " -NoNewline -ForegroundColor Yellow
    $response = [Console]::ReadLine()
    return ($response -match "^[yY]$")
}

# -------------------------------------------------------------------------
# 3. TOOLKIT ACTIONS IMPLEMENTATION (1 - 20 + Extra GUI)
# -------------------------------------------------------------------------

# [1] System Info
function Invoke-SystemInfo {
    Show-ActionHeader "System Information & Diagnostics"
    
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS
    $uptime = (Get-Date) - $os.LastBootUpTime
    $uptimeStr = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    
    Write-Host " Computer Name:  " -NoNewline -ForegroundColor Cyan; Write-Host $env:COMPUTERNAME
    Write-Host " Current User:   " -NoNewline -ForegroundColor Cyan; Write-Host "$env:USERDOMAIN\$env:USERNAME"
    Write-Host " OS Edition:     " -NoNewline -ForegroundColor Cyan; Write-Host "$($os.Caption) ($($os.OSArchitecture))"
    Write-Host " OS Version:     " -NoNewline -ForegroundColor Cyan; Write-Host "$($os.Version) (Build $($os.BuildNumber))"
    Write-Host " Uptime:         " -NoNewline -ForegroundColor Cyan; Write-Host $uptimeStr
    Write-Host " Manufacturer:   " -NoNewline -ForegroundColor Cyan; Write-Host "$($cs.Manufacturer)"
    Write-Host " Model:          " -NoNewline -ForegroundColor Cyan; Write-Host "$($cs.Model)"
    Write-Host " Serial Number:  " -NoNewline -ForegroundColor Cyan; Write-Host "$($bios.SerialNumber)"
    Write-Host " Processor:      " -NoNewline -ForegroundColor Cyan; Write-Host "$($cpu.Name)"
    
    $totalRamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $freeRamGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    Write-Host " Memory (RAM):   " -NoNewline -ForegroundColor Cyan; Write-Host "$([math]::Round($totalRamGB - $freeRamGB, 2)) GB used / $totalRamGB GB total"
    
    # Network IP summary
    Write-Host ""
    Write-Host " Active Network Interfaces:" -ForegroundColor Yellow
    Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias * | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | ForEach-Object {
        Write-Host "   - $($_.InterfaceAlias): $($_.IPAddress)" -ForegroundColor White
    }

    # BitLocker Status
    Write-Host ""
    Write-Host " BitLocker Volume Status:" -ForegroundColor Yellow
    try {
        $bitlocker = Get-BitLockerVolume -ErrorAction SilentlyContinue
        if ($bitlocker) {
            foreach ($vol in $bitlocker) {
                $statusColor = if ($vol.ProtectionStatus -eq 'On') { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
                Write-Host "   - Drive $($vol.MountPoint) Protection: " -NoNewline
                Write-Host "$($vol.ProtectionStatus) ($($vol.VolumeStatus))" -ForegroundColor $statusColor
            }
        } else {
            Write-Host "   BitLocker information not available." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "   Could not query BitLocker status." -ForegroundColor DarkGray
    }
    
    Wait-UserPrompt
}

# [2] SFC Scan
function Invoke-SFCScan {
    Show-ActionHeader "System File Checker (SFC) - Scan & Repair"
    Write-Host "[*] Running: sfc /scannow ..." -ForegroundColor Yellow
    Write-Host "[*] This may take 5-15 minutes. Please wait..." -ForegroundColor Gray
    Write-Host ""
    sfc /scannow
    Wait-UserPrompt
}

# [3] SFC Verify Only
function Invoke-SFCVerifyOnly {
    Show-ActionHeader "System File Checker (SFC) - Verify Only (Non-destructive)"
    Write-Host "[*] Running: sfc /verifyonly ..." -ForegroundColor Yellow
    Write-Host "[*] Scanning integrity without repairing..." -ForegroundColor Gray
    Write-Host ""
    sfc /verifyonly
    Wait-UserPrompt
}

# [4] DISM Scan Health
function Invoke-DISMScanHealth {
    Show-ActionHeader "Deployment Image Servicing and Management (DISM) - Scan Health"
    Write-Host "[*] Running: dism /online /cleanup-image /scanhealth ..." -ForegroundColor Yellow
    Write-Host ""
    dism /online /cleanup-image /scanhealth
    Wait-UserPrompt
}

# [5] DISM Repair (RestoreHealth)
function Invoke-DISMRestoreHealth {
    Show-ActionHeader "DISM Image Repair (RestoreHealth)"
    Write-Host "[*] Running: dism /online /cleanup-image /restorehealth ..." -ForegroundColor Yellow
    Write-Host "[*] Repairing Windows Component Store using Windows Update as source..." -ForegroundColor Gray
    Write-Host ""
    dism /online /cleanup-image /restorehealth
    Wait-UserPrompt
}

# [6] Component Store Cleanup
function Invoke-ComponentStoreCleanup {
    Show-ActionHeader "DISM Component Store Cleanup (ResetBase)"
    Write-Host "[*] This cleans superseded components in WinSxS to recover disk space." -ForegroundColor Gray
    Write-Host "[*] Running: dism /online /cleanup-image /startcomponentcleanup /resetbase ..." -ForegroundColor Yellow
    Write-Host ""
    dism /online /cleanup-image /startcomponentcleanup /resetbase
    Wait-UserPrompt
}

# [7] Drive Health (SMART)
function Invoke-DriveHealth {
    Show-ActionHeader "Storage Drive Health & SMART Status"
    Write-Host "Physical Disk Information:" -ForegroundColor Yellow
    
    try {
        $disks = Get-PhysicalDisk
        $disks | Select-Object DeviceId, FriendlyName, MediaType, OperationalStatus, HealthStatus, Size | Format-Table -AutoSize
        
        Write-Host "Logical Drive Volumes:" -ForegroundColor Yellow
        Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, FileSystem, 
            @{Name="FreeSpace(GB)"; Expression={[math]::Round($_.SizeRemaining/1GB, 2)}},
            @{Name="TotalSize(GB)"; Expression={[math]::Round($_.Size/1GB, 2)}},
            HealthStatus | Format-Table -AutoSize
    }
    catch {
        Write-Host "[-] Error querying disks: $_" -ForegroundColor Red
    }
    
    Wait-UserPrompt
}

# [8] Flush DNS
function Invoke-FlushDNS {
    Show-ActionHeader "Flush & Register DNS Resolver Cache"
    Write-Host "[*] Flushing DNS Cache..." -ForegroundColor Yellow
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    ipconfig /flushdns
    
    Write-Host "[*] Registering DNS records..." -ForegroundColor Yellow
    ipconfig /registerdns
    
    Write-Host "[+] DNS Resolver flushed and re-registered successfully." -ForegroundColor Green
    Wait-UserPrompt
}

# [9] Reset Winsock
function Invoke-ResetWinsock {
    Show-ActionHeader "Reset Winsock Catalog"
    Write-Host "[!] Resetting the Winsock catalog resets TCP/IP network protocol entries." -ForegroundColor Yellow
    if (Confirm-Action "Do you want to proceed?") {
        netsh winsock reset
        Write-Host "[+] Winsock reset completed." -ForegroundColor Green
        Write-Host "[!] A computer restart is strongly recommended to apply changes." -ForegroundColor Yellow
    }
    Wait-UserPrompt
}

# [10] Reset TCP/IP Stack
function Invoke-ResetTCPIP {
    Show-ActionHeader "Reset TCP/IP Network Stack"
    Write-Host "[!] This resets the internet protocol (TCP/IP) to factory defaults." -ForegroundColor Yellow
    if (Confirm-Action "Do you want to proceed?") {
        $tempLog = "$env:TEMP\tcpip_reset.log"
        netsh int ip reset $tempLog
        netsh int ipv6 reset $tempLog
        Write-Host "[+] TCP/IP stack reset completed." -ForegroundColor Green
        Write-Host "[!] A computer restart is recommended." -ForegroundColor Yellow
    }
    Wait-UserPrompt
}

# [11] Battery Report
function Invoke-BatteryReport {
    Show-ActionHeader "Generate Windows Battery Report"
    $isLaptop = (Get-CimInstance Win32_Battery) -ne $null
    if (-not $isLaptop) {
        Write-Host "[!] No battery detected. This system appears to be a Desktop or VM." -ForegroundColor Yellow
    }
    
    $reportPath = "$env:TEMP\battery_report.html"
    Write-Host "[*] Generating battery report at: $reportPath" -ForegroundColor Cyan
    powercfg /batteryreport /output $reportPath
    
    if (Test-Path $reportPath) {
        Write-Host "[+] Report generated successfully. Opening in browser..." -ForegroundColor Green
        Start-Process $reportPath
    }
    Wait-UserPrompt
}

# [12] Performance Report
function Invoke-PerformanceReport {
    Show-ActionHeader "Windows Performance Report & Metrics"
    Write-Host "Collecting 3-second live performance snapshot..." -ForegroundColor Yellow
    
    $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2 | Select-Object -ExpandProperty CounterSamples | Measure-Object -Property CookedValue -Average).Average
    $availMemMB = (Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue
    $diskQueue = (Get-Counter '\PhysicalDisk(_Total)\Current Disk Queue Length').CounterSamples[0].CookedValue
    
    Write-Host ""
    Write-Host " CPU Utilization:        $([math]::Round($cpuUsage, 1))%" -ForegroundColor White
    Write-Host " Available Memory:       $([math]::Round($availMemMB, 0)) MB" -ForegroundColor White
    Write-Host " Current Disk Queue:     $([math]::Round($diskQueue, 2))" -ForegroundColor White
    Write-Host ""
    Write-Host "[*] Launching Windows Performance Monitor (perfmon /report) in background..." -ForegroundColor Cyan
    Start-Process "perfmon.exe" -ArgumentList "/report"
    Wait-UserPrompt
}

# [13] WinRE Info
function Invoke-WinREInfo {
    Show-ActionHeader "Windows Recovery Environment (WinRE) Status"
    reagentc /info
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host " [1] Enable WinRE (reagentc /enable)"
    Write-Host " [2] Disable WinRE (reagentc /disable)"
    Write-Host " [Enter] Skip and return"
    Write-Host "Select option: " -NoNewline -ForegroundColor Cyan
    $choice = [Console]::ReadLine()
    if ($choice -eq "1") {
        reagentc /enable
    } elseif ($choice -eq "2") {
        reagentc /disable
    }
    Wait-UserPrompt
}

# [14] System Restore
function Invoke-SystemRestore {
    Show-ActionHeader "System Restore Configuration"
    Write-Host "Existing System Restore Points:" -ForegroundColor Yellow
    try {
        Get-ComputerRestorePoint | Format-Table -AutoSize
    } catch {
        Write-Host "Unable to list restore points or service is disabled." -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host " [1] Create a new System Restore Point now"
    Write-Host " [2] Launch System Restore Wizard GUI (rstrui.exe)"
    Write-Host " [Enter] Return to menu"
    Write-Host "Select option: " -NoNewline -ForegroundColor Cyan
    $choice = [Console]::ReadLine()
    
    if ($choice -eq "1") {
        Write-Host "Enter description for the restore point: " -NoNewline -ForegroundColor White
        $desc = [Console]::ReadLine()
        if ([string]::IsNullOrWhiteSpace($desc)) { $desc = "IT-Support-RestorePoint" }
        try {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description $desc -RestorePointType "MODIFY_SETTINGS"
            Write-Host "[+] Restore point created." -ForegroundColor Green
        } catch {
            Write-Host "[-] Failed to create restore point: $_" -ForegroundColor Red
        }
    } elseif ($choice -eq "2") {
        Start-Process "rstrui.exe"
    }
    Wait-UserPrompt
}

# [15] Memory Diagnostic
function Invoke-MemoryDiagnostic {
    Show-ActionHeader "Windows Memory Diagnostic (mdsched.exe)"
    Write-Host "[!] This utility tests RAM for hardware faults upon the next system boot." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host " [1] Restart now and check for problems"
    Write-Host " [2] Check for problems next time I start my computer"
    Write-Host " [Enter] Cancel and return to menu"
    Write-Host "Select option: " -NoNewline -ForegroundColor White
    $choice = [Console]::ReadLine()
    
    if ($choice -eq "1") {
        Start-Process "mdsched.exe"
    } elseif ($choice -eq "2") {
        Start-Process "mdsched.exe"
    }
    Wait-UserPrompt
}

# [16] Advanced Startup
function Invoke-AdvancedStartup {
    Show-ActionHeader "Reboot into Windows Advanced Startup / WinRE"
    Write-Host "[!] This will immediately restart your machine into the Windows Recovery Menu" -ForegroundColor Red
    Write-Host "    where you can access Safe Mode, UEFI/BIOS Settings, and Startup Repair." -ForegroundColor Red
    Write-Host ""
    if (Confirm-Action "Are you sure you want to reboot right now into Advanced Startup?") {
        Write-Host "[*] Rebooting in 5 seconds... Save your work!" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        shutdown /r /o /f /t 00
    }
}

# [17] Check Windows Update
function Invoke-CheckWindowsUpdate {
    Show-ActionHeader "Windows Update Troubleshooter & Service Reset"
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host " [1] Open Windows Update Settings"
    Write-Host " [2] Reset Windows Update Services & SoftwareDistribution Cache"
    Write-Host " [Enter] Return to menu"
    Write-Host "Select option: " -NoNewline -ForegroundColor Cyan
    $choice = [Console]::ReadLine()
    
    if ($choice -eq "1") {
        Start-Process "ms-settings:windowsupdate"
    } elseif ($choice -eq "2") {
        Write-Host "[*] Stopping Update Services..." -ForegroundColor Yellow
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name cryptSvc -Force -ErrorAction SilentlyContinue
        Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
        Stop-Service -Name msiserver -Force -ErrorAction SilentlyContinue
        
        Write-Host "[*] Renaming SoftwareDistribution & Catroot2 caches..." -ForegroundColor Yellow
        $time = Get-Date -Format "yyyyMMddHHmmss"
        if (Test-Path "$env:windir\SoftwareDistribution") {
            Rename-Item "$env:windir\SoftwareDistribution" "SoftwareDistribution.old.$time" -ErrorAction SilentlyContinue
        }
        if (Test-Path "$env:windir\System32\catroot2") {
            Rename-Item "$env:windir\System32\catroot2" "catroot2.old.$time" -ErrorAction SilentlyContinue
        }
        
        Write-Host "[*] Restarting Update Services..." -ForegroundColor Yellow
        Start-Service -Name cryptSvc -ErrorAction SilentlyContinue
        Start-Service -Name bits -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Write-Host "[+] Windows Update cache reset successfully." -ForegroundColor Green
    }
    Wait-UserPrompt
}

# [18] Full Report (All Info)
function Invoke-FullReport {
    Show-ActionHeader "Generating Full Comprehensive Diagnostic Report"
    $reportPath = "$env:TEMP\IT_Diagnostic_Report_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    Write-Host "[*] Compiling hardware, storage, network, and system health..." -ForegroundColor Yellow
    
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $disks = Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, Size, SizeRemaining, HealthStatus
    $events = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2} -MaxEvents 15 -ErrorAction SilentlyContinue
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>IT Diagnostic Report - $env:COMPUTERNAME</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #0d1117; color: #c9d1d9; padding: 20px; }
        h1, h2 { color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 8px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #30363d; padding: 8px 12px; text-align: left; }
        th { background-color: #161b22; color: #7ee787; }
        tr:nth-child(even) { background-color: #161b22; }
        .badge-err { color: #ff7b72; font-weight: bold; }
    </style>
</head>
<body>
    <h1>IT Diagnostic Report</h1>
    <p><strong>Generated:</strong> $(Get-Date) | <strong>Computer:</strong> $env:COMPUTERNAME | <strong>User:</strong> $env:USERNAME</p>
    
    <h2>System Information</h2>
    <table>
        <tr><th>Item</th><th>Details</th></tr>
        <tr><td>Operating System</td><td>$($os.Caption) ($($os.Version))</td></tr>
        <tr><td>Architecture</td><td>$($os.OSArchitecture)</td></tr>
        <tr><td>System Model</td><td>$($cs.Manufacturer) $($cs.Model)</td></tr>
        <tr><td>Processor</td><td>$($cpu.Name)</td></tr>
        <tr><td>Total RAM</td><td>$([math]::Round($cs.TotalPhysicalMemory/1GB, 2)) GB</td></tr>
        <tr><td>Last Boot Time</td><td>$($os.LastBootUpTime)</td></tr>
    </table>

    <h2>Drive Storage Status</h2>
    <table>
        <tr><th>Drive</th><th>Label</th><th>Total (GB)</th><th>Free (GB)</th><th>Health</th></tr>
"@

    foreach ($d in $disks) {
        $tot = [math]::Round($d.Size/1GB, 2)
        $free = [math]::Round($d.SizeRemaining/1GB, 2)
        $html += "<tr><td>$($d.DriveLetter):</td><td>$($d.FileSystemLabel)</td><td>$tot</td><td>$free</td><td>$($d.HealthStatus)</td></tr>"
    }

    $html += @"
    </table>

    <h2>Recent System Critical & Error Logs</h2>
    <table>
        <tr><th>Time</th><th>Provider</th><th>Id</th><th>Message</th></tr>
"@

    if ($events) {
        foreach ($e in $events) {
            $msg = [System.Web.HttpUtility]::HtmlEncode($e.Message)
            if ($msg.Length -gt 150) { $msg = $msg.Substring(0, 150) + "..." }
            $html += "<tr><td>$($e.TimeCreated)</td><td>$($e.ProviderName)</td><td>$($e.Id)</td><td class='badge-err'>$msg</td></tr>"
        }
    } else {
        $html += "<tr><td colspan='4'>No recent critical errors found.</td></tr>"
    }

    $html += @"
    </table>
</body>
</html>
"@

    $html | Out-File -FilePath $reportPath -Encoding utf8
    Write-Host "[+] Report generated at: $reportPath" -ForegroundColor Green
    Start-Process $reportPath
    Wait-UserPrompt
}

# [19] Disk Cleanup
function Invoke-DiskCleanup {
    Show-ActionHeader "Windows Disk & Cache Cleanup"
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host " [1] Automatic Quick Purge (Temp files, Prefetch, Crash Dumps, Recycle Bin)"
    Write-Host " [2] Open Standard Cleanmgr Utility (Windows Disk Cleanup)"
    Write-Host " [Enter] Return to menu"
    Write-Host "Select option: " -NoNewline -ForegroundColor Cyan
    $choice = [Console]::ReadLine()
    
    if ($choice -eq "1") {
        Write-Host "[*] Purging User & Windows Temp folders..." -ForegroundColor Yellow
        $tempPaths = @($env:TEMP, "$env:windir\Temp")
        foreach ($tp in $tempPaths) {
            if (Test-Path $tp) {
                Get-ChildItem -Path $tp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Host "[*] Emptying Recycle Bin..." -ForegroundColor Yellow
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        
        Write-Host "[+] Quick disk cleanup complete." -ForegroundColor Green
    } elseif ($choice -eq "2") {
        Start-Process "cleanmgr.exe"
    }
    Wait-UserPrompt
}

# [20] Event Log Errors (Last 20)
function Invoke-EventLogErrors {
    Show-ActionHeader "Recent System & Application Error Events (Last 20)"
    Write-Host "Querying Event Logs..." -ForegroundColor Yellow
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName=@('System','Application'); Level=1,2} -MaxEvents 20 -ErrorAction Stop
        foreach ($ev in $events) {
            $lvl = if ($ev.Level -eq 1) { "CRITICAL" } else { "ERROR" }
            $color = if ($ev.Level -eq 1) { [ConsoleColor]::Red } else { [ConsoleColor]::Yellow }
            
            Write-Host "[$($ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))] " -NoNewline -ForegroundColor DarkGray
            Write-Host "[$lvl] " -NoNewline -ForegroundColor $color
            Write-Host "[$($ev.ProviderName) / ID: $($ev.Id)]" -ForegroundColor Cyan
            $line = ($ev.Message -split "`r?`n")[0]
            if ($line.Length -gt 100) { $line = $line.Substring(0, 100) + "..." }
            Write-Host "  $line" -ForegroundColor Gray
            Write-Host ""
        }
    }
    catch {
        Write-Host "[+] No recent critical or error events found or unable to access event logs." -ForegroundColor Green
    }
    Wait-UserPrompt
}

# -------------------------------------------------------------------------
# 4. SIDEBAR DASHBOARD (32 ADVANCED IT TOOLS)
# -------------------------------------------------------------------------
function Invoke-ModernGUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # â”€â”€ Colours â”€â”€
    $bgDark    = [System.Drawing.Color]::FromArgb(13,  17,  23)
    $bgPanel   = [System.Drawing.Color]::FromArgb(22,  27,  34)
    $bgCard    = [System.Drawing.Color]::FromArgb(22,  27,  34)
    $clrAccent = [System.Drawing.Color]::FromArgb(31, 111, 235)
    $clrText   = [System.Drawing.Color]::FromArgb(230, 237, 243)
    $clrMuted  = [System.Drawing.Color]::FromArgb(110, 118, 129)
    $clrSub    = [System.Drawing.Color]::FromArgb(139, 148, 158)
    $clrBlue   = [System.Drawing.Color]::FromArgb( 88, 166, 255)
    $clrGreen  = [System.Drawing.Color]::FromArgb( 63, 185,  80)
    $clrAmber  = [System.Drawing.Color]::FromArgb(210, 153,  34)
    $clrRed    = [System.Drawing.Color]::FromArgb(248,  81,  73)
    $clrBorder = [System.Drawing.Color]::FromArgb( 48,  54,  61)

    # â”€â”€ Form â”€â”€
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = "IT Support Toolkit"
    $form.Size            = New-Object System.Drawing.Size(1180, 820)
    $form.MinimumSize     = New-Object System.Drawing.Size(900, 680)
    $form.StartPosition   = "CenterScreen"
    $form.BackColor       = $bgDark
    $form.Font            = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable

    # â”€â”€ Title bar (58px top strip) â”€â”€
    $titleBar            = New-Object System.Windows.Forms.Panel
    $titleBar.BackColor  = $bgPanel
    $titleBar.Height     = 58
    $titleBar.Dock       = [System.Windows.Forms.DockStyle]::Top

    $accentLine           = New-Object System.Windows.Forms.Panel
    $accentLine.BackColor = $clrAccent
    $accentLine.Height    = 3
    $accentLine.Dock      = [System.Windows.Forms.DockStyle]::Top
    $titleBar.Controls.Add($accentLine)

    $appIcon          = New-Object System.Windows.Forms.Label
    $appIcon.Text     = [char]0x2699
    $appIcon.Font     = New-Object System.Drawing.Font("Segoe UI", 20)
    $appIcon.ForeColor = $clrAccent
    $appIcon.Location = New-Object System.Drawing.Point(18, 13)
    $appIcon.Size     = New-Object System.Drawing.Size(32, 36)
    $titleBar.Controls.Add($appIcon)

    $appName           = New-Object System.Windows.Forms.Label
    $appName.Text      = "IT Support Toolkit"
    $appName.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 13)
    $appName.ForeColor = $clrText
    $appName.Location  = New-Object System.Drawing.Point(58, 13)
    $appName.Size      = New-Object System.Drawing.Size(300, 26)
    $titleBar.Controls.Add($appName)

    $sessionLbl           = New-Object System.Windows.Forms.Label
    $sessionLbl.Text      = "$env:COMPUTERNAME  -  $env:USERNAME  -  Administrator"
    $sessionLbl.Font      = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $sessionLbl.ForeColor = $clrBlue
    $sessionLbl.Location  = New-Object System.Drawing.Point(58, 38)
    $sessionLbl.Size      = New-Object System.Drawing.Size(500, 16)
    $titleBar.Controls.Add($sessionLbl)

    # â”€â”€ Body panel (holds sidebar + right pane) â”€â”€
    $bodyPanel           = New-Object System.Windows.Forms.Panel
    $bodyPanel.BackColor = $bgDark
    $bodyPanel.Dock      = [System.Windows.Forms.DockStyle]::Fill

    # â”€â”€ Right pane (holds cardHost + console) â”€â”€
    $rightPane           = New-Object System.Windows.Forms.Panel
    $rightPane.BackColor = $bgDark
    $rightPane.Dock      = [System.Windows.Forms.DockStyle]::Fill

    # â”€â”€ Card host: the area where category FlowLayoutPanels live â”€â”€
    $cardHost           = New-Object System.Windows.Forms.Panel
    $cardHost.BackColor = $bgDark
    $cardHost.Dock      = [System.Windows.Forms.DockStyle]::Fill

    # â”€â”€ Console outer (220px bottom) â”€â”€
    $consoleOuter           = New-Object System.Windows.Forms.Panel
    $consoleOuter.BackColor = $bgDark
    $consoleOuter.Height    = 220
    $consoleOuter.Dock      = [System.Windows.Forms.DockStyle]::Bottom

    # Console divider line (1px top)
    $conDivider           = New-Object System.Windows.Forms.Panel
    $conDivider.BackColor = $clrBorder
    $conDivider.Height    = 1
    $conDivider.Dock      = [System.Windows.Forms.DockStyle]::Top

    # Console header bar (34px)
    $conHeaderBar           = New-Object System.Windows.Forms.Panel
    $conHeaderBar.BackColor = $bgPanel
    $conHeaderBar.Height    = 34
    $conHeaderBar.Dock      = [System.Windows.Forms.DockStyle]::Top

    $conTitle           = New-Object System.Windows.Forms.Label
    $conTitle.Text      = "  Output"
    $conTitle.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $conTitle.ForeColor = $clrSub
    $conTitle.Width     = 180
    $conTitle.Dock      = [System.Windows.Forms.DockStyle]::Left
    $conTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

    $clearLbl           = New-Object System.Windows.Forms.Label
    $clearLbl.Text      = "Clear  "
    $clearLbl.Font      = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $clearLbl.ForeColor = $clrBlue
    $clearLbl.Width     = 56
    $clearLbl.Dock      = [System.Windows.Forms.DockStyle]::Right
    $clearLbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $clearLbl.Cursor    = [System.Windows.Forms.Cursors]::Hand

    $hudStatus           = New-Object System.Windows.Forms.Label
    $hudStatus.Text      = "Ready"
    $hudStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $hudStatus.ForeColor = $clrGreen
    $hudStatus.Dock      = [System.Windows.Forms.DockStyle]::Fill
    $hudStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    # Console log box
    $logBox             = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline   = $true
    $logBox.ScrollBars  = [System.Windows.Forms.ScrollBars]::Vertical
    $logBox.ReadOnly    = $true
    $logBox.BackColor   = $bgDark
    $logBox.ForeColor   = [System.Drawing.Color]::FromArgb(201, 209, 217)
    $logBox.Font        = New-Object System.Drawing.Font("Cascadia Code", 9)
    $logBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $logBox.Dock        = [System.Windows.Forms.DockStyle]::Fill
    $logBox.Text        = "  >> IT Support Toolkit ready.`r`n  >> Select a category from the left and click any tool.`r`n"

    $clearLbl.Add_Click({ $logBox.Text = "  >> Output cleared.`r`n" })

    # â”€â”€ Sidebar (230px left) â”€â”€
    $sidebar           = New-Object System.Windows.Forms.Panel
    $sidebar.BackColor = $bgPanel
    $sidebar.Width     = 230
    $sidebar.Dock      = [System.Windows.Forms.DockStyle]::Left

    $sidebarBorder           = New-Object System.Windows.Forms.Panel
    $sidebarBorder.BackColor = $clrBorder
    $sidebarBorder.Width     = 1
    $sidebarBorder.Dock      = [System.Windows.Forms.DockStyle]::Right
    $sidebar.Controls.Add($sidebarBorder)

    $navLabel           = New-Object System.Windows.Forms.Label
    $navLabel.Text      = "  CATEGORIES"
    $navLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
    $navLabel.ForeColor = $clrMuted
    $navLabel.Location  = New-Object System.Drawing.Point(0, 16)
    $navLabel.Size      = New-Object System.Drawing.Size(229, 20)
    $sidebar.Controls.Add($navLabel)

    # â”€â”€ Control hierarchy assembly (docking order: Fill FIRST, then edges) â”€â”€
    # consoleHeader: Fill hudStatus first, then right clearLbl, then left conTitle
    $conHeaderBar.Controls.Add($hudStatus)   # Fill - must be added first
    $conHeaderBar.Controls.Add($clearLbl)    # Right
    $conHeaderBar.Controls.Add($conTitle)    # Left - added last

    # consoleOuter: Fill logBox first, then Top bars
    $consoleOuter.Controls.Add($logBox)       # Fill - must be added first
    $consoleOuter.Controls.Add($conHeaderBar) # Top
    $consoleOuter.Controls.Add($conDivider)   # Top - topmost (added last)

    # rightPane: Fill cardHost first, then Bottom console
    $rightPane.Controls.Add($cardHost)      # Fill - must be added first
    $rightPane.Controls.Add($consoleOuter)  # Bottom - added last

    # bodyPanel: Fill rightPane first, then Left sidebar
    $bodyPanel.Controls.Add($rightPane)  # Fill - must be added first
    $bodyPanel.Controls.Add($sidebar)    # Left - added last

    # form: Fill bodyPanel first, then Top titleBar
    $form.Controls.Add($bodyPanel)  # Fill - must be added first
    $form.Controls.Add($titleBar)   # Top - added last

    # â”€â”€ Category panel dictionary â”€â”€
    $catPanels = [System.Collections.Generic.Dictionary[string, [System.Windows.Forms.FlowLayoutPanel]]]::new()

    # â”€â”€ Tool card factory â”€â”€
    function Add-ToolCard([string]$cat, [string]$title, [string]$desc, [string]$badge, $optionsOrAction, [scriptblock]$actionBlock) {
        $options = $null
        $action  = $null
        if ($optionsOrAction -is [scriptblock]) {
            $action = $optionsOrAction
        } else {
            $options = $optionsOrAction
            $action  = $actionBlock
        }
        # Ensure category FlowLayoutPanel exists inside cardHost
        if (-not $catPanels.ContainsKey($cat)) {
            $fp              = New-Object System.Windows.Forms.FlowLayoutPanel
            $fp.Dock         = [System.Windows.Forms.DockStyle]::Fill
            $fp.BackColor    = $bgDark
            $fp.AutoScroll   = $true
            $fp.Padding      = New-Object System.Windows.Forms.Padding(18, 14, 6, 6)
            $fp.WrapContents = $true
            $fp.Visible      = $false
            $cardHost.Controls.Add($fp)
            $catPanels[$cat] = $fp
        }

        $card           = New-Object System.Windows.Forms.Panel
        $card.Size      = New-Object System.Drawing.Size(308, 88)
        $card.Margin    = New-Object System.Windows.Forms.Padding(0, 0, 10, 10)
        $card.BackColor = $bgCard
        $card.Cursor    = [System.Windows.Forms.Cursors]::Hand

        $bar            = New-Object System.Windows.Forms.Panel
        $bar.Location   = New-Object System.Drawing.Point(0, 0)
        $bar.Size       = New-Object System.Drawing.Size(3, 88)
        $bar.BackColor  = $clrBorder
        $card.Controls.Add($bar)

        $bdg            = New-Object System.Windows.Forms.Label
        $bdg.Text       = $badge
        $bdg.Font       = New-Object System.Drawing.Font("Cascadia Code", 7, [System.Drawing.FontStyle]::Bold)
        $bdg.ForeColor  = $clrBlue
        $bdg.BackColor  = [System.Drawing.Color]::FromArgb(31, 45, 61)
        $bdg.TextAlign  = [System.Drawing.ContentAlignment]::MiddleCenter
        $bdg.Location   = New-Object System.Drawing.Point(230, 12)
        $bdg.Size       = New-Object System.Drawing.Size(66, 20)
        $bdg.Cursor     = [System.Windows.Forms.Cursors]::Hand
        $card.Controls.Add($bdg)

        $ttl            = New-Object System.Windows.Forms.Label
        $ttl.Text       = $title
        $ttl.Font       = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
        $ttl.ForeColor  = $clrText
        $ttl.Location   = New-Object System.Drawing.Point(13, 13)
        $ttl.Size       = New-Object System.Drawing.Size(213, 22)
        $ttl.Cursor     = [System.Windows.Forms.Cursors]::Hand
        $card.Controls.Add($ttl)

        if ($options -and $options.Count -gt 0) {
            $dsc            = New-Object System.Windows.Forms.Label
            $dsc.Text       = $desc
            $dsc.Font       = New-Object System.Drawing.Font("Segoe UI", 8)
            $dsc.ForeColor  = $clrMuted
            $dsc.Location   = New-Object System.Drawing.Point(13, 36)
            $dsc.Size       = New-Object System.Drawing.Size(283, 20)
            $dsc.Cursor     = [System.Windows.Forms.Cursors]::Hand
            $card.Controls.Add($dsc)

            $cmb            = New-Object System.Windows.Forms.ComboBox
            $cmb.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
            $cmb.Font       = New-Object System.Drawing.Font("Segoe UI", 8.5)
            $cmb.BackColor  = [System.Drawing.Color]::FromArgb(13, 17, 23)
            $cmb.ForeColor  = $clrText
            $cmb.Location   = New-Object System.Drawing.Point(13, 56)
            $cmb.Size       = New-Object System.Drawing.Size(280, 24)
            foreach ($opt in $options) { [void]$cmb.Items.Add($opt) }
            $cmb.SelectedIndex = 0
            $card.Controls.Add($cmb)
        } else {
            $dsc            = New-Object System.Windows.Forms.Label
            $dsc.Text       = $desc
            $dsc.Font       = New-Object System.Drawing.Font("Segoe UI", 8.5)
            $dsc.ForeColor  = $clrMuted
            $dsc.Location   = New-Object System.Drawing.Point(13, 39)
            $dsc.Size       = New-Object System.Drawing.Size(283, 38)
            $dsc.Cursor     = [System.Windows.Forms.Cursors]::Hand
            $card.Controls.Add($dsc)
        }

        # Tag-based dispatch pattern (avoids PowerShell closure bug)
        $card.Tag = @{ Title = $title; Block = $action; Root = $card; Cmb = $cmb }
        $bar.Tag  = @{ Root = $card }
        $bdg.Tag  = @{ Root = $card }
        $ttl.Tag  = @{ Root = $card }
        $dsc.Tag  = @{ Root = $card }

        $dispatch = {
            $root = if ($this.Tag.Root) { $this.Tag.Root } else { $this }
            $meta = $root.Tag
            $t    = $meta.Title
            $act  = $meta.Block
            $c    = $meta.Cmb
            $selectedOpt = if ($c) { $c.SelectedItem.ToString() } else { $null }

            $hudStatus.Text      = "Running: $t"
            $hudStatus.ForeColor = $clrAmber
            $logBox.AppendText("`r`n[$(Get-Date -Format 'HH:mm:ss')]  $t`r`n")
            $form.Refresh()
            try {
                $out = if ($null -ne $selectedOpt) { & $act $selectedOpt *>&1 | Out-String } else { & $act *>&1 | Out-String }
                if (-not [string]::IsNullOrWhiteSpace($out)) {
                    $logBox.AppendText($out.TrimEnd())
                    $logBox.AppendText("`r`n")
                }
                $logBox.AppendText("[Done]`r`n")
                $hudStatus.Text      = "Ready"
                $hudStatus.ForeColor = $clrGreen
            } catch {
                $logBox.AppendText("[Error] $_`r`n")
                $hudStatus.Text      = "Error"
                $hudStatus.ForeColor = $clrRed
            }
            $logBox.SelectionStart = $logBox.Text.Length
            $logBox.ScrollToCaret()
        }

        $hoverIn = {
            $root = if ($this.Tag.Root) { $this.Tag.Root } else { $this }
            $root.BackColor           = [System.Drawing.Color]::FromArgb(30, 36, 46)
            $root.Controls[0].BackColor = [System.Drawing.Color]::FromArgb(31, 111, 235)
        }
        $hoverOut = {
            $root = if ($this.Tag.Root) { $this.Tag.Root } else { $this }
            $root.BackColor           = [System.Drawing.Color]::FromArgb(22, 27, 34)
            $root.Controls[0].BackColor = [System.Drawing.Color]::FromArgb(48, 54, 61)
        }

        foreach ($ctrl in @($card, $bar, $bdg, $ttl, $dsc)) {
            $ctrl.Add_Click($dispatch)
            $ctrl.Add_MouseEnter($hoverIn)
            $ctrl.Add_MouseLeave($hoverOut)
        }

        $catPanels[$cat].Controls.Add($card)
    }

    # â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    # TOOL DEFINITIONS
    # â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    # System Audit
    Add-ToolCard "System Audit" "System Overview" "Hardware, CPU, RAM and OS build details" "INFO" {
        $os  = Get-CimInstance Win32_OperatingSystem
        $cs  = Get-CimInstance Win32_ComputerSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $up  = (Get-Date) - $os.LastBootUpTime
        Write-Output "Computer:   $env:COMPUTERNAME"
        Write-Output "User:       $env:USERDOMAIN\$env:USERNAME"
        Write-Output "OS:         $($os.Caption) ($($os.OSArchitecture))"
        Write-Output "Build:      $($os.Version) (Build $($os.BuildNumber))"
        Write-Output "Uptime:     $($up.Days)d $($up.Hours)h $($up.Minutes)m"
        Write-Output "Model:      $($cs.Manufacturer) $($cs.Model)"
        Write-Output "Processor:  $($cpu.Name)"
        Write-Output "RAM:        $([math]::Round($cs.TotalPhysicalMemory/1GB,2)) GB"
    }

    Add-ToolCard "System Audit" "Battery Health Report" "Run powercfg battery capacity diagnostics" "POWER" {
        $path = "$env:TEMP\battery_report.html"
        powercfg /batteryreport /output $path
        if (Test-Path $path) { Start-Process $path; Write-Output "Report opened: $path" }
        else { Write-Output "No battery detected on this device." }
    }

    Add-ToolCard "System Audit" "Drive SMART Health" "Physical disk health status and free space" "DISK" {
        Get-PhysicalDisk | Select-Object DeviceId,FriendlyName,MediaType,HealthStatus | Format-Table | Out-String
        Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter,FileSystemLabel,
            @{N="Free GB";E={[math]::Round($_.SizeRemaining/1GB,2)}},
            @{N="Total GB";E={[math]::Round($_.Size/1GB,2)}},HealthStatus | Format-Table | Out-String
    }

    Add-ToolCard "System Audit" "Live Performance Audit" "CPU load, available RAM, then open PerfMon" "PERF" {
        $cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2 |
            Select-Object -ExpandProperty CounterSamples | Measure-Object -Property CookedValue -Average).Average
        $ramFree = (Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue
        Write-Output "CPU Load:      $([math]::Round($cpuLoad,1))%"
        Write-Output "Available RAM: $([math]::Round($ramFree,0)) MB"
        Start-Process "perfmon.exe" -ArgumentList "/report"
        Write-Output "Launched Performance Monitor."
    }

    Add-ToolCard "System Audit" "Event Log Triage" "Last 20 Critical and Error system events" "LOGS" {
        $evts = Get-WinEvent -FilterHashtable @{LogName=@('System','Application');Level=1,2} -MaxEvents 20 -ErrorAction SilentlyContinue
        if ($evts) {
            foreach ($e in $evts) {
                $lvl = if ($e.Level -eq 1) { "CRITICAL" } else { "ERROR" }
                Write-Output "[$($e.TimeCreated.ToString('HH:mm:ss'))] [$lvl] $($e.ProviderName): $($e.Message.Split([char]10)[0])"
            }
        } else { Write-Output "No critical events found in System or Application logs." }
    }

    Add-ToolCard "System Audit" "HTML Audit Report" "Generate a dark-mode HTML system report" "HTML" {
        $rpt  = "$env:TEMP\IT_Audit_${env:COMPUTERNAME}_$(Get-Date -Format yyyyMMdd_HHmmss).html"
        $os   = Get-CimInstance Win32_OperatingSystem
        $vol  = Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter,FileSystemLabel,Size,SizeRemaining
        $rows = ($vol | ForEach-Object {
            $f = [math]::Round($_.SizeRemaining/1GB,2)
            $t = [math]::Round($_.Size/1GB,2)
            "            <tr><td>$($_.DriveLetter):</td><td>$($_.FileSystemLabel)</td><td>$f</td><td>$t</td></tr>"
        }) -join "`n"
        $ts  = Get-Date
        $css = "body{font-family:system-ui,sans-serif;background:#0d1117;color:#e6edf3;padding:30px}table{width:100%;border-collapse:collapse;margin-top:10px}th,td{padding:10px;border-bottom:1px solid #21262d;text-align:left}th{color:#58a6ff}"
        $html = @"
<!DOCTYPE html><html><head><title>IT Audit</title><style>$css</style></head><body>
<h2>IT Audit - $env:COMPUTERNAME</h2><p>$($os.Caption) $($os.Version) | $ts</p>
<h3>Storage</h3><table><tr><th>Drive</th><th>Label</th><th>Free GB</th><th>Total GB</th></tr>
$rows
</table></body></html>
"@
        $html | Out-File $rpt -Encoding utf8
        Start-Process $rpt
        Write-Output "Report saved: $rpt"
    }

    Add-ToolCard "System Audit" "Installed Drivers Audit" "Enumerate third-party kernel drivers" "DRV" {
        Write-Output "Third-Party Drivers:"
        pnputil /enum-drivers | Select-Object -First 40
    }

    Add-ToolCard "System Audit" "Services Triage" "Automatic services that are not running" "SVC" {
        Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' } |
            Select-Object Name,DisplayName,Status | Format-Table | Out-String
    }

    # Kernel and DISM
    Add-ToolCard "Kernel + DISM" "SFC Full Scan" "Verify and repair protected Windows system files" "SFC" {
        Write-Output "Running sfc /scannow..."
        sfc /scannow
    }

    Add-ToolCard "Kernel + DISM" "SFC Verify Only" "Check integrity without making any changes" "VRFY" {
        Write-Output "Running sfc /verifyonly..."
        sfc /verifyonly
    }

    Add-ToolCard "Kernel + DISM" "DISM Scan Health" "Check Windows image component store for corruption" "DISM" {
        Write-Output "Running DISM ScanHealth..."
        dism /online /cleanup-image /scanhealth
    }

    Add-ToolCard "Kernel + DISM" "DISM Restore Health" "Repair component store via Windows Update" "HEAL" {
        Write-Output "Running DISM RestoreHealth..."
        dism /online /cleanup-image /restorehealth
    }

    Add-ToolCard "Kernel + DISM" "Component Store Cleanup" "Purge superseded update files from WinSxS" "WIM" {
        Write-Output "Cleaning component store..."
        dism /online /cleanup-image /startcomponentcleanup /resetbase
    }

    Add-ToolCard "Kernel + DISM" "Rebuild Perf Counters" "Reset corrupted Lodctr performance counters" "LDCTR" {
        lodctr /R
        Write-Output "Performance counters rebuilt."
    }

    Add-ToolCard "Kernel + DISM" "Chkdsk Scan" "Scan C: file system for errors (read-only)" "CHKD" {
        Write-Output "Scanning C: volume bitmap..."
        chkdsk C: /scan
    }

    Add-ToolCard "Kernel + DISM" "Rebuild Icon Cache" "Clear corrupted Explorer icon and font caches" "ICON" {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue
        Start-Process explorer.exe
        Write-Output "Icon cache cleared and Explorer restarted."
    }

    # Network
    # Network Tools & DNS Config
    Add-ToolCard "Network" "Speedtest (Ookla)" "Run Speedtest.net CLI test for latency, download & upload" "SPEED" {
        Write-Output "Running Internet Speed Test..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $cli = Get-Command speedtest -ErrorAction SilentlyContinue
            if (-not $cli) {
                Write-Output "Installing Ookla Speedtest CLI via Winget..."
                winget install --id Ookla.Speedtest -e --accept-source-agreements --accept-package-agreements | Out-Null
            }
        }
        $cliPath = Get-Command speedtest -ErrorAction SilentlyContinue
        if ($cliPath) {
            & speedtest --accept-license --accept-gdpr
        } else {
            Write-Output "Fast.com / Ookla fallback: Testing download speed using web stream..."
            $testUrl = "https://speed.hetzner.de/100MB.bin"
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $wc = New-Object System.Net.WebClient
            try {
                $data = $wc.DownloadData($testUrl)
                $sw.Stop()
                $mb = $data.Length / 1MB
                $sec = $sw.Elapsed.TotalSeconds
                $mbps = [math]::Round(($mb * 8) / $sec, 2)
                Write-Output "Download Speed: $mbps Mbps (Downloaded $($mb)MB in $([math]::Round($sec,2))s)"
            } catch {
                Write-Output "Speed test fallback failed. Opening speedtest.net in browser..."
                Start-Process "https://www.speedtest.net"
            }
        }
    }

    Add-ToolCard "Network" "Configure DNS Server" "Select provider & click card to apply" "DNS" @(
        "Google (8.8.8.8, 8.8.4.4)",
        "Cloudflare (1.1.1.1, 1.0.0.1)",
        "AdGuard - No Ads (94.140.14.14)",
        "Automatic (DHCP / Default)"
    ) {
        param($selection)
        Write-Output "Selected DNS Provider: $selection"
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.PhysicalMediaType -ne 'Unspecified' }

        switch -Wildcard ($selection) {
            "*Google*" {
                foreach ($a in $adapters) {
                    Set-DnsClientServerAddress -InterfaceAlias $a.Name -ServerAddresses ("8.8.8.8","8.8.4.4") -ErrorAction SilentlyContinue
                    Write-Output "Updated adapter: $($a.Name) -> 8.8.8.8, 8.8.4.4"
                }
            }
            "*Cloudflare*" {
                foreach ($a in $adapters) {
                    Set-DnsClientServerAddress -InterfaceAlias $a.Name -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue
                    Write-Output "Updated adapter: $($a.Name) -> 1.1.1.1, 1.0.0.1"
                }
            }
            "*AdGuard*" {
                foreach ($a in $adapters) {
                    Set-DnsClientServerAddress -InterfaceAlias $a.Name -ServerAddresses ("94.140.14.14","94.140.15.15") -ErrorAction SilentlyContinue
                    Write-Output "Updated adapter: $($a.Name) -> 94.140.14.14, 94.140.15.15"
                }
            }
            "*Automatic*" {
                foreach ($a in $adapters) {
                    Set-DnsClientServerAddress -InterfaceAlias $a.Name -ResetServerAddresses -ErrorAction SilentlyContinue
                    Write-Output "Reset adapter: $($a.Name) -> Automatic (DHCP)"
                }
            }
        }
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Output "DNS configuration applied and DNS cache flushed."
    }
    Add-ToolCard "Network" "Flush DNS Cache" "Clear DNS resolver cache and re-register DNS" "DNS" {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        ipconfig /flushdns
        ipconfig /registerdns
        Write-Output "DNS cache flushed and re-registered."
    }

    Add-ToolCard "Network" "Reset Winsock" "Reset network socket layer to factory defaults" "SOCK" {
        netsh winsock reset
        Write-Output "Winsock reset. Reboot recommended."
    }

    Add-ToolCard "Network" "Reset TCP/IP Stack" "Reset IPv4 and IPv6 stack configurations" "TCPIP" {
        $log = "$env:TEMP\tcpip_reset.log"
        netsh int ip reset $log
        netsh int ipv6 reset $log
        Write-Output "TCP/IP stacks reset. Log: $log"
    }

    Add-ToolCard "Network" "Renew DHCP Lease" "Release and renew IP address from DHCP server" "DHCP" {
        ipconfig /release
        ipconfig /renew
        Write-Output "DHCP lease renewed."
    }

    Add-ToolCard "Network" "Active Port Map" "List all listening ports with owning process IDs" "PORT" {
        Get-NetTCPConnection -State Listen |
            Select-Object LocalAddress,LocalPort,OwningProcess | Sort-Object LocalPort | Format-Table | Out-String
    }

    Add-ToolCard "Network" "Restart Network Adapters" "Cycle all physical network interface cards" "NIC" {
        Write-Output "Restarting physical network adapters..."
        Get-NetAdapter | Where-Object { $_.PhysicalMediaType -ne 'Unspecified' } | Restart-NetAdapter
        Write-Output "Adapters cycled."
    }

    Add-ToolCard "Network" "DNS Server Benchmark" "Test query latency to Cloudflare, Google, Quad9" "BNCH" {
        foreach ($s in @("1.1.1.1","8.8.8.8","9.9.9.9")) {
            $ms = (Measure-Command { Resolve-DnsName -Name "google.com" -Server $s -ErrorAction SilentlyContinue }).TotalMilliseconds
            Write-Output "DNS $s  ->  $([math]::Round($ms,1)) ms"
        }
    }

    # Security
    Add-ToolCard "Security" "Defender Quick Scan" "Invoke Windows Defender antivirus quick scan" "AV" {
        Write-Output "Starting Windows Defender Quick Scan..."
        Start-MpScan -ScanType QuickScan
        Write-Output "Quick scan complete."
    }

    Add-ToolCard "Security" "Update AV Signatures" "Fetch the latest Microsoft Defender definitions" "DEFS" {
        Write-Output "Updating Defender signatures..."
        Update-MpSignature
        Write-Output "Security intelligence updated."
    }

    Add-ToolCard "Security" "Firewall Profile Status" "Inspect Domain, Private and Public firewall rules" "FW" {
        Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction | Format-Table | Out-String
    }

    Add-ToolCard "Security" "Local Admins Audit" "List all members of the local Administrators group" "ADM" {
        Write-Output "Local Administrators:"
        Get-LocalGroupMember -Group "Administrators" | Select-Object Name,PrincipalSource,ObjectClass | Format-Table | Out-String
    }

    Add-ToolCard "Security" "Startup Inspection" "Inspect autorun registry keys and startup tasks" "AUTO" {
        Write-Output "Startup programs:"
        Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User | Format-Table | Out-String
    }

    Add-ToolCard "Security" "BitLocker Status" "Check drive encryption status and key protectors" "BL" {
        manage-bde -status
    }

    # Maintenance
    Add-ToolCard "Maintenance" "Deep Storage Purge" "Clear Temp, Prefetch, crash dumps and Recycle Bin" "PURGE" {
        foreach ($p in @($env:TEMP,"$env:windir\Temp","$env:windir\Prefetch")) {
            if (Test-Path $p) {
                Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Output "Temp folders and Recycle Bin cleared."
    }

    Add-ToolCard "Maintenance" "Reset Windows Update" "Purge update cache and restart WU services" "WU" {
        Stop-Service -Name wuauserv,cryptSvc,bits,msiserver -Force -ErrorAction SilentlyContinue
        $ts = Get-Date -Format "yyyyMMddHHmmss"
        if (Test-Path "$env:windir\SoftwareDistribution") {
            Rename-Item "$env:windir\SoftwareDistribution" "SoftwareDistribution.old.$ts" -ErrorAction SilentlyContinue
        }
        Start-Service -Name cryptSvc,bits,wuauserv -ErrorAction SilentlyContinue
        Write-Output "Windows Update cache reset and services restarted."
    }

    Add-ToolCard "Maintenance" "WinRE Status" "Inspect Windows Recovery Environment partition" "RE" {
        reagentc /info
    }

    Add-ToolCard "Maintenance" "Create Restore Point" "Snapshot current system state for rollback" "SNAP" {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "IT-Toolkit-Checkpoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
        Write-Output "System restore point created."
    }

    Add-ToolCard "Maintenance" "Memory Diagnostic" "Schedule Windows Memory Diagnostic on next boot" "RAM" {
        Start-Process "mdsched.exe"
        Write-Output "Memory Diagnostic scheduled for next reboot."
    }

    Add-ToolCard "Maintenance" "Advanced Startup Reboot" "Reboot into UEFI firmware or WinRE recovery" "BOOT" {
        $r = [System.Windows.Forms.MessageBox]::Show("Restart into Advanced Startup now?","Confirm","YesNo","Question")
        if ($r -eq "Yes") {
            Write-Output "Rebooting into Advanced Startup in 5 seconds..."
            Start-Sleep -Seconds 5
            shutdown /r /o /f /t 00
        } else { Write-Output "Reboot cancelled." }
    }

    # â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    # â”€â”€ Extra System Audit tools â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Add-ToolCard "System Audit" "Installed Hotfixes" "List all installed Windows updates and patches" "PATCH" {
        Get-HotFix | Select-Object HotFixID, Description, InstalledOn | Sort-Object InstalledOn -Descending |
            Format-Table | Out-String
    }

    Add-ToolCard "System Audit" "GPU / Display Info" "Enumerate display adapters and monitor details" "GPU" {
        Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, VideoModeDescription,
            @{N="VRAM(MB)";E={[math]::Round($_.AdapterRAM/1MB,0)}} | Format-Table | Out-String
        Get-CimInstance Win32_DesktopMonitor | Select-Object Name, ScreenWidth, ScreenHeight | Format-Table | Out-String
    }

    # â”€â”€ Extra Network tools â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Add-ToolCard "Network" "Full IP Configuration" "Complete ipconfig /all output for all adapters" "IPCFG" {
        ipconfig /all
    }

    Add-ToolCard "Network" "Connectivity Ping Test" "Ping Cloudflare, Google and local gateway" "PING" {
        foreach ($h in @("1.1.1.1","8.8.8.8","192.168.1.1")) {
            $r = Test-Connection -ComputerName $h -Count 2 -ErrorAction SilentlyContinue
            if ($r) { Write-Output "OK    $h  avg $([math]::Round(($r | Measure-Object ResponseTime -Average).Average,0)) ms" }
            else     { Write-Output "FAIL  $h  unreachable" }
        }
    }

    Add-ToolCard "Network" "Traceroute to Internet" "Trace hops to 8.8.8.8 to find routing issues" "TRACE" {
        tracert -d -h 20 8.8.8.8
    }

    # â”€â”€ Extra Security tools â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Add-ToolCard "Security" "Defender Real-Time Status" "Show Windows Defender real-time protection state" "RT" {
        $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($mp) {
            Write-Output "Real-Time Protection : $($mp.RealTimeProtectionEnabled)"
            Write-Output "Antivirus Enabled    : $($mp.AntivirusEnabled)"
            Write-Output "Signature Version    : $($mp.AntivirusSignatureVersion)"
            Write-Output "Last Quick Scan      : $($mp.QuickScanEndTime)"
            Write-Output "Last Full Scan       : $($mp.FullScanEndTime)"
        } else { Write-Output "Unable to query Defender status." }
    }

    Add-ToolCard "Security" "Shared Folders Audit" "List all active network shares on this machine" "SHARE" {
        Get-SmbShare | Select-Object Name, Path, Description, ShareState | Format-Table | Out-String
    }

    # â”€â”€ Extra Maintenance tools â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Add-ToolCard "Maintenance" "Optimize Drives" "Run Defrag or TRIM on all eligible volumes" "OPTIM" {
        Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
            Write-Output "Optimizing $($_.DriveLetter): $($_.FileSystemLabel)..."
            Optimize-Volume -DriveLetter $_.DriveLetter -Verbose 2>&1 | Out-String
        }
    }

    Add-ToolCard "Maintenance" "Clear Event Logs" "Wipe all Windows event logs (irreversible)" "CLRLOG" {
        $r = [System.Windows.Forms.MessageBox]::Show("Clear ALL Windows event logs? This cannot be undone.","Confirm","YesNo","Warning")
        if ($r -eq "Yes") {
            Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object RecordCount -gt 0 | ForEach-Object {
                try { [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName) }
                catch { }
            }
            Write-Output "All Windows event logs cleared."
        } else { Write-Output "Cancelled." }
    }

    Add-ToolCard "Maintenance" "Check Windows Update" "Check for pending Windows updates via wuauclt" "WUA" {
        Write-Output "Triggering Windows Update detection..."
        Start-Process "wuauclt.exe" -ArgumentList "/detectnow"
        Start-Process "ms-settings:windowsupdate"
        Write-Output "Windows Update opened. Check the Settings window."
    }

    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    # SOFTWARE INSTALLER TAB
    # â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    Add-ToolCard "Software" "7-Zip" "Free open-source file archiver with high compression" "FREE" {
        Write-Output "Installing 7-Zip..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id 7zip.7-Zip -e --accept-source-agreements --accept-package-agreements
        } else {
            $dst = "$env:TEMP\7z-setup.exe"
            Write-Output "Downloading 7-Zip installer..."
            (New-Object System.Net.WebClient).DownloadFile("https://www.7-zip.org/a/7z2407-x64.exe", $dst)
            Start-Process $dst -Wait
        }
        Write-Output "Done."
    }

    Add-ToolCard "Software" "VLC Media Player" "Free, open-source multimedia player for all formats" "FREE" {
        Write-Output "Installing VLC..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id VideoLAN.VLC -e --accept-source-agreements --accept-package-agreements
        } else {
            Start-Process "https://www.videolan.org/vlc/download-windows.html"
            Write-Output "Opened VLC download page in browser."
        }
        Write-Output "Done."
    }

    Add-ToolCard "Software" "RustDesk" "Open-source self-hosted remote desktop solution" "REMOTE" {
        Write-Output "Installing RustDesk..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id RustDesk.RustDesk -e --accept-source-agreements --accept-package-agreements
        } else {
            Start-Process "https://github.com/rustdesk/rustdesk/releases/latest"
            Write-Output "Opened RustDesk latest releases page in browser."
        }
        Write-Output "Done."
    }

    Add-ToolCard "Software" "AnyDesk" "Fast, lightweight remote desktop and support tool" "REMOTE" {
        Write-Output "Installing AnyDesk..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id AnyDesk.AnyDesk -e --accept-source-agreements --accept-package-agreements
        } else {
            $dst = "$env:TEMP\AnyDeskSetup.exe"
            Write-Output "Downloading AnyDesk..."
            (New-Object System.Net.WebClient).DownloadFile("https://download.anydesk.com/AnyDesk.exe", $dst)
            Start-Process $dst -Wait
        }
        Write-Output "Done."
    }

    Add-ToolCard "Software" "Quick Assist" "Microsoft built-in remote support and screen sharing" "MS" {
        Write-Output "Launching Quick Assist..."
        $qa = Get-Command quickassist -ErrorAction SilentlyContinue
        if ($qa) {
            Start-Process "quickassist"
            Write-Output "Quick Assist launched."
        } else {
            Start-Process "ms-windows-store://pdp/?ProductId=9P7BP5VNWKX5"
            Write-Output "Opened Quick Assist in Microsoft Store."
        }
    }

    Add-ToolCard "Software" "Brave Browser" "Privacy-focused Chromium browser with built-in ad blocking" "FREE" {
        Write-Output "Installing Brave Browser..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Brave.Brave -e --accept-source-agreements --accept-package-agreements
        } else {
            $dst = "$env:TEMP\BraveSetup.exe"
            Write-Output "Downloading Brave..."
            (New-Object System.Net.WebClient).DownloadFile("https://laptop-updates.brave.com/latest/winx64", $dst)
            Start-Process $dst -Wait
        }
        Write-Output "Done."
    }

    Add-ToolCard "Software" "Mozilla Firefox" "Trusted open-source browser by Mozilla Foundation" "FREE" {
        Write-Output "Installing Firefox..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Mozilla.Firefox -e --accept-source-agreements --accept-package-agreements
        } else {
            $dst = "$env:TEMP\FirefoxSetup.exe"
            Write-Output "Downloading Firefox..."
            (New-Object System.Net.WebClient).DownloadFile("https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US", $dst)
            Start-Process $dst -Wait
        }
        Write-Output "Done."
    }

    Add-ToolCard "Software" "PDFgear" "Free PDF editor, reader and converter with AI features" "FREE" {
        Write-Output "Installing PDFgear..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id PDFgear.PDFgear -e --accept-source-agreements --accept-package-agreements
        } else {
            Start-Process "https://www.pdfgear.com/download/"
            Write-Output "Opened PDFgear download page in browser."
        }
        Write-Output "Done."
    }

    Add-ToolCard "Software" "Office 2021 (English)" "Microsoft Office Professional Plus 2021 - English (EN-US)" "MS" {
        $url = "https://officecdn.microsoft.com/db/492350f6-3a01-4f97-b9c0-c7c6ddf67d60/media/en-us/ProPlus2021Retail.img"
        $dst = "$env:TEMP\ProPlus2021Retail_EN.img"
        Write-Output "Starting Office 2021 English download (~4 GB). Please wait..."
        Write-Output "Download location: $dst"
        try {
            Start-BitsTransfer -Source $url -Destination $dst -ErrorAction Stop
            Write-Output "Download complete. Mounting disk image..."
            $mount  = Mount-DiskImage -ImagePath $dst -PassThru
            $letter = ($mount | Get-Volume).DriveLetter
            Write-Output "Running Office setup from drive $letter..."
            Start-Process "$letter`:\setup.exe"
            Write-Output "Office installer launched. Dismount the drive after installation completes."
        } catch {
            Write-Output "Error: $_"
            Write-Output "Manual download URL: $url"
        }
    }

    Add-ToolCard "Software" "Office 2021 (Arabic)" "Microsoft Office Professional Plus 2021 - Arabic (AR-SA)" "MS" {
        $url = "https://officecdn.microsoft.com/db/492350f6-3a01-4f97-b9c0-c7c6ddf67d60/media/ar-sa/ProPlus2021Retail.img"
        $dst = "$env:TEMP\ProPlus2021Retail_AR.img"
        Write-Output "Starting Office 2021 Arabic download (~4 GB). Please wait..."
        Write-Output "Download location: $dst"
        try {
            Start-BitsTransfer -Source $url -Destination $dst -ErrorAction Stop
            Write-Output "Download complete. Mounting disk image..."
            $mount  = Mount-DiskImage -ImagePath $dst -PassThru
            $letter = ($mount | Get-Volume).DriveLetter
            Write-Output "Running Office setup from drive $letter..."
            Start-Process "$letter`:\setup.exe"
            Write-Output "Office installer launched. Dismount the drive after installation completes."
        } catch {
            Write-Output "Error: $_"
            Write-Output "Manual download URL: $url"
        }
    }

    # SIDEBAR NAV BUTTONS
    # â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    # Category key -> Segoe MDL2 Assets glyph (all within BMP, [char] is fine)
    $cats = [ordered]@{
        "System Audit"  = [char]0xE770   # System/Dashboard
        "Kernel + DISM" = [char]0xE90F   # Repair/Wrench
        "Network"       = [char]0xE968   # Network
        "Security"      = [char]0xE72E   # Lock
        "Maintenance"   = [char]0xE74D   # Recycle/Clean
        "Software"      = [char]0xE896   # Download/Install
    }

    $navBtns = @()
    $navY    = 44

    foreach ($entry in $cats.GetEnumerator()) {
        $catName = $entry.Key
        $catIcon = $entry.Value

        $btn           = New-Object System.Windows.Forms.Panel
        $btn.Location  = New-Object System.Drawing.Point(0, $navY)
        $btn.Size      = New-Object System.Drawing.Size(229, 46)
        $btn.BackColor = [System.Drawing.Color]::Transparent
        $btn.Cursor    = [System.Windows.Forms.Cursors]::Hand

        $ico           = New-Object System.Windows.Forms.Label
        $ico.Text      = [string]$catIcon
        $ico.Font      = New-Object System.Drawing.Font("Segoe MDL2 Assets", 12)
        $ico.ForeColor = $clrMuted
        $ico.Location  = New-Object System.Drawing.Point(14, 12)
        $ico.Size      = New-Object System.Drawing.Size(22, 22)
        $ico.Cursor    = [System.Windows.Forms.Cursors]::Hand
        $btn.Controls.Add($ico)

        $lbl           = New-Object System.Windows.Forms.Label
        $lbl.Text      = $catName
        $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 9.5)
        $lbl.ForeColor = $clrSub
        $lbl.Location  = New-Object System.Drawing.Point(44, 13)
        $lbl.Size      = New-Object System.Drawing.Size(172, 20)
        $lbl.Cursor    = [System.Windows.Forms.Cursors]::Hand
        $btn.Controls.Add($lbl)

        # Store metadata in Tag for closure-safe dispatch
        $btn.Tag = @{ Cat = $catName; Ico = $ico; Lbl = $lbl }
        $ico.Tag = @{ Parent = $btn }
        $lbl.Tag = @{ Parent = $btn }

        $sidebar.Controls.Add($btn)
        $navBtns += $btn
        $navY    += 52
    }

    # Switch category scriptblock
    $switchCat = {
        param([string]$target)
        foreach ($nb in $navBtns) {
            $nb.BackColor         = [System.Drawing.Color]::Transparent
            $nb.Tag.Lbl.ForeColor = $clrSub
            $nb.Tag.Ico.ForeColor = $clrMuted
        }
        foreach ($fp in $catPanels.Values) { $fp.Visible = $false }
        foreach ($nb in $navBtns) {
            if ($nb.Tag.Cat -eq $target) {
                $nb.BackColor         = [System.Drawing.Color]::FromArgb(30, 36, 46)
                $nb.Tag.Lbl.ForeColor = $clrBlue
                $nb.Tag.Ico.ForeColor = $clrBlue
                break
            }
        }
        if ($catPanels.ContainsKey($target)) { $catPanels[$target].Visible = $true }
    }

    # Wire click events on each nav button
    foreach ($nb in $navBtns) {
        $nb.Tag["SwitchFn"] = $switchCat

        $navClick = {
            $root = if ($this.Tag.Parent) { $this.Tag.Parent } else { $this }
            $fn   = $root.Tag.SwitchFn
            $cat  = $root.Tag.Cat
            & $fn $cat
        }
        $nb.Add_Click($navClick)
        $nb.Controls[0].Add_Click($navClick)  # icon
        $nb.Controls[1].Add_Click($navClick)  # label
    }

    # Activate first category on open
    & $switchCat "System Audit"

    [void]$form.ShowDialog()
}

# -------------------------------------------------------------------------
# 5. MAIN MENU LOOP (Terminal Mode)
# -------------------------------------------------------------------------
function Start-ToolkitMenu {
    Set-ConsoleTheme
    
    while ($true) {
        Write-ToolkitHeader
        
        # 2-column layout matching the user's uploaded image
        $menuItems = @(
            @{ LeftKey = " 1"; LeftText = "System Info";              RightKey = "10"; RightText = "Reset TCP/IP" },
            @{ LeftKey = " 2"; LeftText = "SFC Scan";                 RightKey = "11"; RightText = "Battery Report" },
            @{ LeftKey = " 3"; LeftText = "SFC Verify Only";          RightKey = "12"; RightText = "Performance Report" },
            @{ LeftKey = " 4"; LeftText = "DISM Scan Health";         RightKey = "13"; RightText = "WinRE Info" },
            @{ LeftKey = " 5"; LeftText = "DISM Repair (RestoreH.)";  RightKey = "14"; RightText = "System Restore" },
            @{ LeftKey = " 6"; LeftText = "Component Store Cleanup";  RightKey = "15"; RightText = "Memory Diagnostic" },
            @{ LeftKey = " 7"; LeftText = "Drive Health (SMART)";     RightKey = "16"; RightText = "Advanced Startup" },
            @{ LeftKey = " 8"; LeftText = "Flush DNS";                RightKey = "17"; RightText = "Check Windows Update" },
            @{ LeftKey = " 9"; LeftText = "Reset Winsock";            RightKey = "18"; RightText = "Full Report (All Info)" },
            @{ LeftKey = "19"; LeftText = "Disk Cleanup";             RightKey = "20"; RightText = "Event Log Errors (last 20)" }
        )

        foreach ($row in $menuItems) {
            $leftSide  = "[{0}] {1}" -f $row.LeftKey.Trim(), $row.LeftText
            $rightSide = "[{0}] {1}" -f $row.RightKey.Trim(), $row.RightText
            Write-Host ("  {0,-38} {1}" -f $leftSide, $rightSide) -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "  [G] APEX Command Center GUI (32 Tools)" -ForegroundColor Cyan
        Write-Host "  [Q] Exit" -ForegroundColor Red
        Write-Host ""
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGreen
        Write-Host "Select [1-20 / G / Q]: " -NoNewline -ForegroundColor Green
        
        $choice = [Console]::ReadLine()
        if ($null -eq $choice) { break }
        $choice = $choice.Trim()

        switch ($choice.ToUpper()) {
            "1"  { Invoke-SystemInfo }
            "2"  { Invoke-SFCScan }
            "3"  { Invoke-SFCVerifyOnly }
            "4"  { Invoke-DISMScanHealth }
            "5"  { Invoke-DISMRestoreHealth }
            "6"  { Invoke-ComponentStoreCleanup }
            "7"  { Invoke-DriveHealth }
            "8"  { Invoke-FlushDNS }
            "9"  { Invoke-ResetWinsock }
            "10" { Invoke-ResetTCPIP }
            "11" { Invoke-BatteryReport }
            "12" { Invoke-PerformanceReport }
            "13" { Invoke-WinREInfo }
            "14" { Invoke-SystemRestore }
            "15" { Invoke-MemoryDiagnostic }
            "16" { Invoke-AdvancedStartup }
            "17" { Invoke-CheckWindowsUpdate }
            "18" { Invoke-FullReport }
            "19" { Invoke-DiskCleanup }
            "20" { Invoke-EventLogErrors }
            "G"  { Invoke-ModernGUI }
            "Q"  { 
                Write-Host "Exiting IT Administration Repair Toolkit. Goodbye!" -ForegroundColor Cyan
                return 
            }
            default {
                Write-Host "Invalid option. Please choose between 1-20, G, or Q." -ForegroundColor Yellow
                Start-Sleep -Milliseconds 1200
            }
        }
    }
}

# Entrypoint
Start-ToolkitMenu