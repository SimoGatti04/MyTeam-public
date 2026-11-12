# Script PowerShell per installare FFmpeg tramite winget
# Questo script viene incluso nel bundle Windows dell'app

param(
    [switch]$Silent = $false
)

$ErrorActionPreference = "Stop"

# Verifica se winget è disponibile
try {
    $wingetVersion = winget --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "winget non trovato"
    }
} catch {
    Write-Host "ERRORE: winget non è installato o non disponibile." -ForegroundColor Red
    Write-Host "winget è incluso in Windows 10 versione 1809+ e Windows 11." -ForegroundColor Yellow
    Write-Host "Installa Microsoft Store e aggiorna Windows per ottenere winget." -ForegroundColor Yellow
    exit 1
}

# Verifica se FFmpeg è già installato
try {
    $ffmpegVersion = ffmpeg -version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "FFmpeg è già installato." -ForegroundColor Green
        $version = ($ffmpegVersion | Select-String "ffmpeg version (\S+)" | ForEach-Object { $_.Matches[0].Groups[1].Value })
        if ($version) {
            Write-Host "Versione: $version" -ForegroundColor Green
        }
        exit 0
    }
} catch {
    # FFmpeg non trovato, procediamo con l'installazione
}

# Installa FFmpeg tramite winget
Write-Host "Installazione FFmpeg tramite winget..." -ForegroundColor Cyan

try {
    if ($Silent) {
        # Modalità silenziosa (per uso programmatico)
        winget install --id gyan.FFmpeg --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    } else {
        # Modalità interattiva (mostra output)
        winget install --id gyan.FFmpeg --accept-package-agreements --accept-source-agreements
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "FFmpeg installato con successo!" -ForegroundColor Green
        
        # Trova il percorso di installazione di winget
        # winget installa in: C:\Users\<User>\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_*
        $userProfile = $env:USERPROFILE
        $wingetPackagesPath = Join-Path $userProfile "AppData\Local\Microsoft\WinGet\Packages"
        
        $ffmpegPath = $null
        if (Test-Path $wingetPackagesPath) {
            # Cerca la cartella Gyan.FFmpeg
            $ffmpegFolders = Get-ChildItem -Path $wingetPackagesPath -Filter "Gyan.FFmpeg_*" -Directory -ErrorAction SilentlyContinue
            if ($ffmpegFolders) {
                foreach ($folder in $ffmpegFolders) {
                    # Cerca ffmpeg.exe nella struttura (ffmpeg-*-full_build\bin\ffmpeg.exe)
                    $binPath = Get-ChildItem -Path $folder.FullName -Recurse -Filter "ffmpeg.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($binPath) {
                        $ffmpegPath = $binPath.Directory.FullName
                        Write-Host "FFmpeg trovato in: $ffmpegPath" -ForegroundColor Cyan
                        break
                    }
                }
            }
        }
        
        # Se trovato, aggiungi al PATH
        if ($ffmpegPath) {
            Write-Host "Aggiunta FFmpeg al PATH..." -ForegroundColor Cyan
            
            # Ottieni PATH utente corrente
            $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
            
            # Verifica se già presente
            if ($currentUserPath -notlike "*$ffmpegPath*") {
                # Aggiungi al PATH utente
                $newUserPath = if ($currentUserPath) { "$currentUserPath;$ffmpegPath" } else { $ffmpegPath }
                [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
                
                Write-Host "FFmpeg aggiunto al PATH utente." -ForegroundColor Green
                
                # Aggiorna PATH della sessione corrente
                $env:Path = "$env:Path;$ffmpegPath"
            } else {
                Write-Host "FFmpeg già presente nel PATH." -ForegroundColor Green
            }
        }
        
        # Verifica installazione
        Start-Sleep -Seconds 1  # Attendi che il PATH sia aggiornato
        try {
            $ffmpegVersion = ffmpeg -version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $version = ($ffmpegVersion | Select-String "ffmpeg version (\S+)" | ForEach-Object { $_.Matches[0].Groups[1].Value })
                Write-Host "Versione installata: $version" -ForegroundColor Green
                Write-Host ""
                Write-Host "FFmpeg è ora disponibile nel PATH!" -ForegroundColor Green
                exit 0
            }
        } catch {
            if ($ffmpegPath) {
                Write-Host "FFmpeg installato in: $ffmpegPath" -ForegroundColor Yellow
                Write-Host "Riavvia l'applicazione per applicare le modifiche al PATH." -ForegroundColor Yellow
            } else {
                Write-Host "FFmpeg installato ma percorso non trovato." -ForegroundColor Yellow
                Write-Host "Riavvia l'applicazione per applicare le modifiche al PATH." -ForegroundColor Yellow
            }
            exit 0
        }
    } else {
        Write-Host "ERRORE: Installazione FFmpeg fallita." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERRORE durante l'installazione: $_" -ForegroundColor Red
    exit 1
}

