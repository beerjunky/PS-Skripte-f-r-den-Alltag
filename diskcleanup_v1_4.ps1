<# 
    =====================================================================================
    Script: FullDiskCleanupUltimate.ps1
    Author: CGfromRGAG
    Date: 25.11.2024
    Version: 1.5
    =====================================================================================
    Description:
    Dieses Skript bereinigt alle bekannten Speicherfresser und Dateileichen auf einem
    Windows-System. Es umfasst:
    - Temporäre Dateien
    - Downloads-Ordner
    - Alte Windows-Versionen (Windows.old)
    - Schattenkopien
    - Protokolldateien
    - Windows Update Cache
    - Prefetch-Dateien
    - Speicherabbild-Dateien
    - WinSxS-Ordner
    - Microsoft Store Cache
    - Benutzer-Protokolldateien (z. B. Fehlerberichte)
    - OneDrive Temp-Dateien
    - Offline-Webseiten-Cache
    Am Ende wird eine detaillierte Zusammenfassung der bereinigten Bereiche ausgegeben.
    =====================================================================================
#>

# Sicherstellen, dass das Skript als Administrator ausgeführt wird
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Dieses Skript muss als Administrator ausgeführt werden!" -ForegroundColor Red
    exit
}

# Speicher für die Ergebnisse
$results = @()

function Log-Result {
    param (
        [string]$TaskName,
        [bool]$Success,
        [string]$Message
    )
    $results += [PSCustomObject]@{
        Task     = $TaskName
        Status   = if ($Success) { "✅ Erfolgreich" } else { "❌ Fehlgeschlagen" }
        Details  = $Message
    }

    # Farbige Ausgabe je nach Status
    if ($Success) {
        Write-Host "${TaskName}: ${Message}" -ForegroundColor Green
    } else {
        Write-Host "${TaskName}: ${Message}" -ForegroundColor Red
    }
}

# Speicherplatzanzeige
Write-Host "Freigegebener Speicherplatz pro Laufwerk:" -ForegroundColor Yellow
foreach ($drive in $freeSpaceBefore.Keys) {
    if ($freeSpaceAfter.ContainsKey($drive)) {
        $spaceFreed = $freeSpaceAfter[$drive] - $freeSpaceBefore[$drive]
        Write-Host "${drive}: $([math]::Round($spaceFreed, 2)) GB" -ForegroundColor Green
    }
}


# Funktion: Speicherplatz für jedes Laufwerk messen (nur lokale Festplatten)
function Get-FreeSpacePerDrive {
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ge 0 -and $_.Root -ne $null }
    $driveSpaces = @{}
    foreach ($drive in $drives) {
        $driveSpaces[$drive.Name] = $drive.Free / 1GB # Freier Speicher in GB
    }
    return $driveSpaces
}

# Bereinigungsfunktionen

function Clear-TempFiles {
    Write-Host "Bereinige temporäre Dateien..." -ForegroundColor Yellow
    try {
        Get-ChildItem -Path "C:\Users\*\AppData\Local\Temp" -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path "C:\Windows\Temp" -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-TempFiles" -Success $true -Message "Temporäre Dateien bereinigt."
    } catch {
        Log-Result -TaskName "Clear-TempFiles" -Success $false -Message "Fehler: $_"
    }
}

function Clear-Downloads {
    Write-Host "Bereinige Downloads-Ordner..." -ForegroundColor Yellow
    try {
        Get-ChildItem -Path "C:\Users\*\Downloads" -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-Downloads" -Success $true -Message "Downloads-Ordner bereinigt."
    } catch {
        Log-Result -TaskName "Clear-Downloads" -Success $false -Message "Fehler: $_"
    }
}

function Clear-ShadowCopies {
    Write-Host "Bereinige alte Schattenkopien..." -ForegroundColor Yellow
    try {
        vssadmin delete shadows /all /quiet
        Log-Result -TaskName "Clear-ShadowCopies" -Success $true -Message "Schattenkopien gelöscht."
    } catch {
        Log-Result -TaskName "Clear-ShadowCopies" -Success $false -Message "Fehler: $_"
    }
}

function Clear-WinSxS {
    Write-Host "Bereinige WinSxS-Ordner..." -ForegroundColor Yellow
    try {
        dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
        Log-Result -TaskName "Clear-WinSxS" -Success $true -Message "WinSxS-Ordner bereinigt."
    } catch {
        Log-Result -TaskName "Clear-WinSxS" -Success $false -Message "Fehler: $_"
    }
}

function Clear-Prefetch {
    Write-Host "Bereinige Prefetch-Dateien..." -ForegroundColor Yellow
    try {
        Remove-Item -Path "C:\Windows\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-Prefetch" -Success $true -Message "Prefetch-Dateien bereinigt."
    } catch {
        Log-Result -TaskName "Clear-Prefetch" -Success $false -Message "Fehler: $_"
    }
}

function Clear-MemoryDump {
    Write-Host "Bereinige Speicherabbild-Dateien..." -ForegroundColor Yellow
    try {
        Remove-Item -Path "C:\Windows\Minidump\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\MEMORY.DMP" -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-MemoryDump" -Success $true -Message "Speicherabbild-Dateien bereinigt."
    } catch {
        Log-Result -TaskName "Clear-MemoryDump" -Success $false -Message "Fehler: $_"
    }
}

function Clear-StoreCache {
    Write-Host "Bereinige Microsoft Store Cache..." -ForegroundColor Yellow
    try {
        wsreset.exe
        Log-Result -TaskName "Clear-StoreCache" -Success $true -Message "Microsoft Store Cache bereinigt."
    } catch {
        Log-Result -TaskName "Clear-StoreCache" -Success $false -Message "Fehler: $_"
    }
}

function Clear-ErrorReports {
    Write-Host "Bereinige Fehlerberichte und Diagnosedaten..." -ForegroundColor Yellow
    try {
        Remove-Item -Path "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\ReportArchive\*" -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-ErrorReports" -Success $true -Message "Fehlerberichte bereinigt."
    } catch {
        Log-Result -TaskName "Clear-ErrorReports" -Success $false -Message "Fehler: $_"
    }
}

function Clear-OneDriveTemp {
    Write-Host "Bereinige OneDrive Cache..." -ForegroundColor Yellow
    try {
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-OneDriveTemp" -Success $true -Message "OneDrive-Cache bereinigt."
    } catch {
        Log-Result -TaskName "Clear-OneDriveTemp" -Success $false -Message "Fehler: $_"
    }
}

function Clear-OfflineCache {
    Write-Host "Bereinige Offline-Webseiten-Cache..." -ForegroundColor Yellow
    try {
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\WebCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-OfflineCache" -Success $true -Message "Offline-Webseiten-Cache bereinigt."
    } catch {
        Log-Result -TaskName "Clear-OfflineCache" -Success $false -Message "Fehler: $_"
    }
}

# Hauptskript

Write-Host "Starte Bereinigungsprozess..." -ForegroundColor Yellow
$freeSpaceBefore = Get-FreeSpacePerDrive

Clear-TempFiles
Clear-Downloads
Clear-ShadowCopies
Clear-WinSxS
Clear-Prefetch
Clear-MemoryDump
Clear-StoreCache
Clear-ErrorReports
Clear-OneDriveTemp
Clear-OfflineCache

$freeSpaceAfter = Get-FreeSpacePerDrive
Write-Host "Freigegebener Speicherplatz pro Laufwerk:" -ForegroundColor Yellow
foreach ($drive in $freeSpaceBefore.Keys) {
    if ($freeSpaceAfter.ContainsKey($drive)) {
        $spaceFreed = $freeSpaceAfter[$drive] - $freeSpaceBefore[$drive]
        Write-Host "$drive $([math]::Round($spaceFreed, 2)) GB" -ForegroundColor Green
    }
}

Write-Host "Bereinigungszusammenfassung:" -ForegroundColor Yellow
$results | Format-Table -AutoSize
Write-Host "Bereinigungsprozess abgeschlossen!" -ForegroundColor Green
