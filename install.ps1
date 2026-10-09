# Instalador do xv para Windows (Windows PowerShell 5.1+ / PowerShell 7+).
#   irm https://raw.githubusercontent.com/ViniciusQuatrin/xv/main/install.ps1 | iex
# Instala yt-dlp e FFmpeg via winget, copia xv.ps1 + xv.cmd para %LOCALAPPDATA%\xv
# e adiciona %LOCALAPPDATA%\xv\bin (onde fica o xv.cmd) ao PATH do usuario.

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$RepoRaw = if ($env:XV_REPO_RAW) { $env:XV_REPO_RAW } else { 'https://raw.githubusercontent.com/ViniciusQuatrin/xv/main' }
$Dest = Join-Path $env:LOCALAPPDATA 'xv'
$BinDir = Join-Path $Dest 'bin'

function Info([string]$m) { Write-Host "==> $m" }
function Warn([string]$m) { Write-Host "AVISO: $m" -ForegroundColor Yellow }

# --- dependencias -----------------------------------------------------------
if ($env:XV_NO_DEPS -ne '1') {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        foreach ($pkg in @(@{ Id = 'yt-dlp.yt-dlp'; Cmd = 'yt-dlp' }, @{ Id = 'Gyan.FFmpeg'; Cmd = 'ffmpeg' })) {
            if (Get-Command $pkg.Cmd -ErrorAction SilentlyContinue) {
                Info "$($pkg.Cmd) ja instalado"
                continue
            }
            Info "winget install $($pkg.Id)"
            & winget install --id $pkg.Id -e --source winget --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) { Warn "winget falhou para $($pkg.Id) (codigo $LASTEXITCODE)" }
        }
    }
    else {
        Warn 'winget nao encontrado. Instale o "App Installer" pela Microsoft Store, ou instale manualmente yt-dlp e ffmpeg.'
    }
}

# --- arquivos ---------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $Dest, $BinDir | Out-Null
$local = $null
if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'xv.ps1'))) { $local = $PSScriptRoot }

foreach ($f in @(@{ Name = 'xv.ps1'; To = $Dest }, @{ Name = 'xv.cmd'; To = $BinDir })) {
    $target = Join-Path $f.To $f.Name
    if ($local) {
        Info "copiando $($f.Name) para $target"
        Copy-Item -LiteralPath (Join-Path $local $f.Name) -Destination $target -Force
    }
    else {
        Info "baixando $($f.Name) para $target"
        Invoke-WebRequest -UseBasicParsing -Uri "$RepoRaw/$($f.Name)" -OutFile $target
    }
    try { Unblock-File -LiteralPath $target } catch { }
}

# --- PATH do usuario --------------------------------------------------------
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @()
if ($userPath) { $parts = $userPath -split ';' | Where-Object { $_ } }
if ($parts -notcontains $BinDir) {
    $newPath = (@($parts) + $BinDir) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Info "adicionado $BinDir ao PATH do usuario"
}

# Atualiza o PATH desta sessao (inclui o que o winget acabou de instalar)
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

Write-Host ''
foreach ($c in 'yt-dlp', 'ffmpeg') {
    if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Warn "$c ainda nao esta no PATH (abra um novo terminal; se persistir, reinstale)" }
}
Info 'pronto! Abra um NOVO terminal e use: xv [-g] "<link do X/Twitter>"'
