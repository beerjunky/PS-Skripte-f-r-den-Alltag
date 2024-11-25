<# 
    =====================================================================================
    Script: FullDiskCleanupUltimate.ps1
    Author: CGfromRGAG
    Date: 20.11.2024
    Version: 1.3
    =====================================================================================
    Description:
    Dieses Skript bereinigt alle bekannten Speicherfresser und Dateileichen auf einem
    Windows-System. Dazu gehören:
    - Temporäre Dateien
    - Downloads-Ordner
    - Alte Windows-Versionen (Windows.old)
    - Schattenkopien
    - Protokolldateien
    - Windows Update Cache
    - Prefetch-Dateien
    - Speicherabbild-Dateien
    - Ordner WinSxS
    Am Ende wird eine detaillierte Zusammenfassung der bereinigten Bereiche ausgegeben.
    =====================================================================================
#>

# Sicherstellen, dass das Skript als Administrator ausgeführt wird
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Dieses Skript muss als Administrator ausgeführt werden!"
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
        Status   = if ($Success) { "Erfolgreich" } else { "Fehlgeschlagen" }
        Details  = $Message
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

# Funktion: Papierkorb aller Benutzer leeren
function Clear-RecycleBin {
    Write-Output "Leere den Papierkorb aller Benutzer..."
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.Namespace(10)
        if ($recycleBin.Items().Count -gt 0) {
            $recycleBin.Items() | ForEach-Object { $recycleBin.InvokeVerb("delete") }
            Log-Result -TaskName "Clear-RecycleBin" -Success $true -Message "Papierkorb geleert."
        } else {
            Log-Result -TaskName "Clear-RecycleBin" -Success $true -Message "Papierkorb war bereits leer."
        }
    } catch {
        Log-Result -TaskName "Clear-RecycleBin" -Success $false -Message "Fehler: $_"
    }
}

# Funktion: Temporäre Dateien bereinigen
function Clear-TempFiles {
    Write-Output "Bereinige temporäre Dateien..."
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

# Funktion: Downloads-Ordner bereinigen
function Clear-Downloads {
    Write-Output "Bereinige Downloads-Ordner..."
    try {
        Get-ChildItem -Path "C:\Users\*\Downloads" -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-Downloads" -Success $true -Message "Downloads-Ordner bereinigt."
    } catch {
        Log-Result -TaskName "Clear-Downloads" -Success $false -Message "Fehler: $_"
    }
}

# Funktion: Windows Update Cache bereinigen
function Clear-WindowsUpdateCache {
    Write-Output "Bereinige Windows Update Cache..."
    try {
        Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-WindowsUpdateCache" -Success $true -Message "Windows Update Cache bereinigt."
    } catch {
        Log-Result -TaskName "Clear-WindowsUpdateCache" -Success $false -Message "Fehler: $_"
    }
}

# Funktion: Schattenkopien löschen
function Clear-ShadowCopies {
    Write-Output "Bereinige alte Schattenkopien..."
    try {
        vssadmin delete shadows /all /quiet
        Log-Result -TaskName "Clear-ShadowCopies" -Success $true -Message "Schattenkopien gelöscht."
    } catch {
        Log-Result -TaskName "Clear-ShadowCopies" -Success $false -Message "Fehler: $_"
    }
}

# Funktion: Protokolldateien löschen
function Clear-SystemLogs {
    Write-Output "Bereinige System-Protokolldateien..."
    try {
        Get-ChildItem -Path "C:\Windows\Logs\CBS\*" -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path "C:\Windows\System32\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-SystemLogs" -Success $true -Message "System-Protokolldateien bereinigt."
    } catch {
        Log-Result -TaskName "Clear-SystemLogs" -Success $false -Message "Fehler: $_"
    }
}

# Funktion: Alte Windows-Version entfernen
function Clear-OldOS {
    Write-Output "Bereinige alte Windows-Version..."
    try {
        Remove-Item -Path "C:\Windows.old" -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-OldOS" -Success $true -Message "Alte Windows-Version (Windows.old) entfernt."
    } catch {
        Log-Result -TaskName "Clear-OldOS" -Success $false -Message "Fehler: $_"
    }
}

# Funktion: Prefetch-Dateien bereinigen
function Clear-Prefetch {
    Write-Output "Bereinige Prefetch-Dateien..."
    try {
        Remove-Item -Path "C:\Windows\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-Prefetch" -Success $true -Message "Prefetch-Dateien bereinigt."
    } catch {
        Log-Result -TaskName "Clear-Prefetch" -Success $false -Message "Fehler: $_"
    }
}

# Funktion: Speicherabbild-Dateien bereinigen
function Clear-DumpFiles {
    Write-Output "Bereinige Speicherabbild-Dateien..."
    try {
        Remove-Item -Path "C:\Windows\Minidump\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\MEMORY.DMP" -Force -ErrorAction SilentlyContinue
        Log-Result -TaskName "Clear-DumpFiles" -Success $true -Message "Speicherabbild-Dateien bereinigt."
    } catch {
        Log-Result -TaskName "Clear-DumpFiles" -Success $false -Message "Fehler: $_"
    }
}

# Hauptskript
Write-Output "Starte Bereinigungsprozess..."

# Speicherplatz vor der Bereinigung
$freeSpaceBefore = Get-FreeSpacePerDrive
Write-Output "Freier Speicherplatz vor Bereinigung pro Laufwerk:"
$freeSpaceBefore.GetEnumerator() | ForEach-Object { Write-Output "$($_.Key): $([math]::Round($_.Value, 2)) GB" }

# Bereinigung durchführen
Clear-RecycleBin
Clear-TempFiles
Clear-Downloads
Clear-WindowsUpdateCache
Clear-ShadowCopies
Clear-SystemLogs
Clear-OldOS
Clear-Prefetch
Clear-DumpFiles

# Speicherplatz nach der Bereinigung
$freeSpaceAfter = Get-FreeSpacePerDrive
Write-Output "Freier Speicherplatz nach Bereinigung pro Laufwerk:"
$freeSpaceAfter.GetEnumerator() | ForEach-Object { Write-Output "$($_.Key): $([math]::Round($_.Value, 2)) GB" }

# Berechnung des freigegebenen Speicherplatzes pro Laufwerk
Write-Output "Insgesamt freigegebener Speicherplatz pro Laufwerk:"
foreach ($drive in $freeSpaceBefore.Keys) {
    if ($freeSpaceAfter.ContainsKey($drive)) {
        $spaceFreed = $freeSpaceAfter[$drive] - $freeSpaceBefore[$drive]
        Write-Output "$drive $([math]::Round($spaceFreed, 2)) GB"
    }
}

# Zusammenfassung der Bereinigung
Write-Output "Bereinigungszusammenfassung:"
$results | Format-Table -AutoSize

Write-Output "Bereinigungsprozess abgeschlossen!"
