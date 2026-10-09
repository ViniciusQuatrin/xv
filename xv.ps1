# xv - baixa o video de um post do X/Twitter e copia o ARQUIVO para a area de transferencia.
# Uso: xv [-g] <link>     (-g converte para .gif)
# Windows PowerShell 5.1+ / PowerShell 7+. https://github.com/ViniciusQuatrin/xv
# Sem bloco param() de proposito: assim "-g" chega em $args como texto.

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$OK = [char]::ConvertFromUtf32(0x2705)

function Fail([string]$msg, [int]$code = 1) {
    [Console]::Error.WriteLine($msg)
    exit $code
}

$a = @($args)
$gif = $false
if ($a.Count -gt 0 -and ($a[0] -eq '-g' -or $a[0] -eq '--gif' -or $a[0] -eq '/g')) {
    $gif = $true
    $a = @($a | Select-Object -Skip 1)
}
if ($a.Count -gt 0 -and ($a[0] -eq '-h' -or $a[0] -eq '--help' -or $a[0] -eq '/?')) {
    Write-Output 'uso: xv [-g] <link>'
    Write-Output '  -g  converte o video para .gif'
    exit 0
}
if ($a.Count -lt 1 -or [string]::IsNullOrWhiteSpace([string]$a[0])) { Fail 'uso: xv [-g] <link>' }
$url = [string]$a[0]

# --- pasta de destino -------------------------------------------------------
if ($env:XV_DIR) { $dir = $env:XV_DIR }
else { $dir = Join-Path $env:USERPROFILE 'Videos\twitter-videos' }
New-Item -ItemType Directory -Force -Path $dir | Out-Null

# --- dependencias -----------------------------------------------------------
if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
    Fail 'yt-dlp nao encontrado. Instale: winget install yt-dlp.yt-dlp'
}
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Fail 'ffmpeg nao encontrado. Instale: winget install Gyan.FFmpeg'
}

# --- download ---------------------------------------------------------------
$start = Get-Date
$ErrorActionPreference = 'Continue'
$out = & yt-dlp -q --no-warnings --encoding utf-8 `
    -f 'bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b' --merge-output-format mp4 `
    -o (Join-Path $dir '%(id)s.%(ext)s') --print 'after_move:filepath' $url 2>$null
$rc = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($rc -ne 0) { Fail 'falhou ao baixar' }

$files = @($out | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() } |
    Where-Object { Test-Path -LiteralPath $_ })
if ($files.Count -eq 0) {
    # Fallback (ex.: caminho com acentos mal decodificado): arquivos novos na pasta
    $files = @(Get-ChildItem -LiteralPath $dir -File |
        Where-Object { $_.LastWriteTime -ge $start.AddSeconds(-2) -and $_.Extension -ne '.part' } |
        Sort-Object LastWriteTime | ForEach-Object { $_.FullName })
}
if ($files.Count -eq 0) { Fail 'falhou ao baixar' }

# --- gif --------------------------------------------------------------------
if ($gif) {
    $vf = "fps=15,scale='min(480,iw)':-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"
    for ($i = 0; $i -lt $files.Count; $i++) {
        $src = $files[$i]
        $dst = [IO.Path]::ChangeExtension($src, '.gif')
        $ErrorActionPreference = 'Continue'
        & ffmpeg -nostdin -y -loglevel error -i $src -vf $vf $dst
        $rc = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($rc -ne 0 -or -not (Test-Path -LiteralPath $dst)) { Fail 'falhou ao converter' }
        Remove-Item -LiteralPath $src -Force
        $files[$i] = $dst
    }
}

# --- area de transferencia (CF_HDROP: cola como arquivo no Explorer, WhatsApp, Slack...) ---
$copied = $false
try {
    $sc = Get-Command Set-Clipboard -ErrorAction SilentlyContinue
    if ($sc -and $sc.Parameters.ContainsKey('Path')) {
        # Windows PowerShell 5.1
        Set-Clipboard -LiteralPath $files
        $copied = $true
    }
    elseif ([Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA') {
        # PowerShell 7 (Set-Clipboard nao tem -Path) em thread STA
        Add-Type -AssemblyName System.Windows.Forms
        $list = New-Object System.Collections.Specialized.StringCollection
        foreach ($f in $files) { [void]$list.Add($f) }
        [System.Windows.Forms.Clipboard]::SetFileDropList($list)
        $copied = $true
    }
    else {
        # Thread MTA: delega para o Windows PowerShell em modo STA
        $quoted = ($files | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ','
        & powershell.exe -NoProfile -STA -Command "Set-Clipboard -LiteralPath @($quoted)"
        $copied = ($LASTEXITCODE -eq 0)
    }
}
catch { $copied = $false }

if (-not $copied) {
    [Console]::Error.WriteLine('falhou ao copiar para a area de transferencia.')
    foreach ($f in $files) { Write-Output "arquivo salvo em: $f" }
    exit 2
}
foreach ($f in $files) { Write-Output "$OK copiado: $f" }
