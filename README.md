# IT Administration Repair Toolkit (Windows)

A lightweight, automated troubleshooting and diagnostic suite for Windows IT Support specialists and system administrators. Inspired by the classic IT repair toolkit terminal interface and [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil).

Runs directly from PowerShell via a single command or locally on Windows 10, Windows 11, and Windows Server.

---

## ⚡ Quick Start (One-Liner Execution)

Launch directly in Windows PowerShell (Admin recommended, or allow the auto-elevation prompt):

```powershell
irm https://raw.githubusercontent.com/iN4sser/IT-Support-Tools/main/toolkit.ps1 | iex
```

> **Alternative (Short URL / Custom Domain)**:  
> You can easily point a custom domain or URL shortener (e.g. `bit.ly/win-fix`) directly to the raw URL above to run:
> ```powershell
> irm bit.ly/win-fix | iex
> ```

---

## 🖥️ Local Usage

1. Clone or download this repository.
2. Double-click `start.bat` (automatically elevates to Administrator and starts the toolkit).
   - Or open PowerShell as Administrator and run:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\toolkit.ps1
   ```

---

## 🛠️ Included Tools & Diagnostics

The toolkit features the 20 core tools shown in the terminal layout, plus an optional graphical dashboard:

| # | Tool | Description |
|---|------|-------------|
| **[1]** | **System Info** | OS, build, hardware model, uptime, RAM, active IP addresses & BitLocker drive protection. |
| **[2]** | **SFC Scan** | Scans and repairs corrupted Windows system files (`sfc /scannow`). |
| **[3]** | **SFC Verify Only** | Verifies file integrity without modifying files (`sfc /verifyonly`). |
| **[4]** | **DISM Scan Health** | Checks if the Windows component store corruption is detected. |
| **[5]** | **DISM Repair (RestoreHealth)** | Repairs damaged Windows component store images via Windows Update / online source. |
| **[6]** | **Component Store Cleanup** | Purges superseded components (`dism ... /resetbase`) to reclaim disk space. |
| **[7]** | **Drive Health (SMART)** | Physical disk health status, media type (SSD/NVMe/HDD), and partition space usage. |
| **[8]** | **Flush DNS** | Clears client resolver cache and registers DNS records (`ipconfig /flushdns & /registerdns`). |
| **[9]** | **Reset Winsock** | Resets Winsock catalog to clean up broken network LSP/socket hooks. |
| **[10]**| **Reset TCP/IP** | Resets TCP/IP and IPv6 stacks to factory defaults. |
| **[11]**| **Battery Report** | Generates an official Windows battery health report HTML and opens it in browser. |
| **[12]**| **Performance Report** | Takes real-time performance snapshots (CPU, memory, disk queue) and triggers `perfmon /report`. |
| **[13]**| **WinRE Info** | Checks Windows Recovery Environment status and toggles enable/disable state. |
| **[14]**| **System Restore** | Lists existing restore points, creates new restore points, or opens `rstrui.exe`. |
| **[15]**| **Memory Diagnostic** | Schedules memory hardware testing via `mdsched.exe`. |
| **[16]**| **Advanced Startup** | Safely restarts system directly into Windows Recovery / UEFI / Safe Mode boot menu. |
| **[17]**| **Check Windows Update** | Launches update settings or stops services and resets corrupted update cache directories. |
| **[18]**| **Full Report (All Info)** | Generates a clean HTML diagnostic dashboard summarizing hardware, disks, and error logs. |
| **[19]**| **Disk Cleanup** | Fast purge of user/system temp directories and Recycle Bin, or opens standard `cleanmgr`. |
| **[20]**| **Event Log Errors (Last 20)** | Queries recent Critical and Error events in System & Application logs for rapid triage. |
| **[G]** | **Modern GUI Dashboard** | Launches a native GUI dashboard grouping tools by category. |

---

## 🔒 Security & Privacy Notice

- **Enterprise & Public-Repo Safe**: Contains **no** hardcoded credentials, tokens, proprietary URLs, or telemetry.
- **Zero Third-Party Binary Dependencies**: Uses native Windows utilities (`dism`, `sfc`, `netsh`, `reagentc`, `cim`, etc.) and standard .NET assemblies.
- **Safety Prompts**: Destructive or reboot actions require explicit confirmation (`y/N`) before proceeding.

---

## 📄 License

Released under the [MIT License](LICENSE).
