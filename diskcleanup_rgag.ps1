<# 
    =====================================================================================
    Script: FullDiskCleanupUltimate.ps1
    Author: CGfromRGAG
    Date:20.11.2024
    Versi..: 1.1
    =====================================================================================
    Description:
    Dieses Skript bereinigt alle bekannten Speicherfresser und Dateileichen von einem
    Windows-System, einschließlich temporärer Dateien, alter Windows-Versionen, Schattenkopien,
    und vieles mehr.
    =====================================================================================
#>

# Sicherstellen, dass das Skript als Administrator ausgeführt wird
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Dieses Skript muss als Administrator ausgeführt werden!"
    exit
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
    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.Namespace(10)
    if ($recycleBin.Items().Count -gt 0) {
        $recycleBin.Items() | ForEach-Object { $recycleBin.InvokeVerb("delete") }
        Write-Output "Papierkorb wurde geleert."
    } else {
        Write-Output "Papierkorb ist bereits leer."
    }
}

# Funktion: Temporäre Dateien bereinigen
function Clear-TempFiles {
    Write-Output "Bereinige temporäre Dateien..."
    Get-ChildItem -Path "C:\Users\*\AppData\Local\Temp" -Recurse -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "C:\Windows\Temp" -Recurse -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "Temporäre Dateien wurden bereinigt."
}

# Funktion: Downloads-Ordner bereinigen
function Clear-Downloads {
    Write-Output "Bereinige Downloads-Ordner..."
    Get-ChildItem -Path "C:\Users\*\Downloads" -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "Downloads-Ordner wurde bereinigt."
}

# Funktion: Windows Update Cache bereinigen
function Clear-WindowsUpdateCache {
    Write-Output "Bereinige Windows Update Cache..."
    Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "Windows Update Cache bereinigt."
}

# Funktion: Schattenkopien löschen
function Clear-ShadowCopies {
    Write-Output "Bereinige alte Schattenkopien..."
    vssadmin delete shadows /all /quiet
    Write-Output "Alte Schattenkopien wurden gelöscht."
}

# Funktion: Alte Treiber entfernen
function Clear-OldDrivers {
    Write-Output "Bereinige alte Treiber..."
    pnputil.exe /enum-drivers | ForEach-Object {
        $driver = $_
        if ($driver -match "Published Name") {
            $name = $driver -replace "Published Name\s*:\s*", ""
            pnputil.exe /delete-driver $name /uninstall /force
        }
    }
    Write-Output "Alte Treiber wurden bereinigt."
}

# Funktion: System-Protokolldateien löschen
function Clear-SystemLogs {
    Write-Output "Bereinige System-Protokolldateien..."
    Get-ChildItem -Path "C:\Windows\Logs\CBS\*" -Recurse -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "C:\Windows\System32\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "System-Protokolldateien wurden bereinigt."
}

# Funktion: Alte Windows-Version entfernen
function Clear-OldOS {
    Write-Output "Bereinige alte Windows-Version..."
    Remove-Item -Path "C:\Windows.old" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "Alte Windows-Version wurde bereinigt."
}

# Funktion: Prefetch Der Ordner C:\Windows\Prefetch enthält temporäre Dateien
function clearprefetch {
Write-Output "Bereinige Prefetch-Dateien..."
Remove-Item -Path "C:\Windows\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "Prefetch-Dateien bereinigt."
}

# Funktion:WER
function WER {
Write-Output "Bereinige Windows Error Reporting Dateien..."
Remove-Item -Path "C:\ProgramData\Microsoft\Windows\WER\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "Windows Error Reporting Dateien bereinigt."
}

# Funktion:Dumps
function Dumps {
Write-Output "Bereinige Speicherabbild-Dateien..."
Remove-Item -Path "C:\Windows\Minidump\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\MEMORY.DMP" -Force -ErrorAction SilentlyContinue
Write-Output "Speicherabbild-Dateien bereinigt."

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
Clear-OldDrivers
Clear-SystemLogs
Clear-OldOS
clearprefetch
WER
dumps

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

Write-Output "Bereinigungsprozess abgeschlossen!"
