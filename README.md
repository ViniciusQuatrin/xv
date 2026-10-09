# xv

Baixa o vídeo de um post do **X/Twitter** e já deixa o **arquivo** na área de transferência — é só colar no WhatsApp, Slack, Telegram, Discord, Finder, Explorer…

```sh
xv https://x.com/usuario/status/1234567890
# ✅ copiado: /home/voce/Videos/twitter-videos/1234567890.mp4
```

Funciona no **macOS**, **Linux** e **Windows**. Usa [yt-dlp](https://github.com/yt-dlp/yt-dlp) para baixar e [ffmpeg](https://ffmpeg.org) para juntar áudio/vídeo e gerar GIFs.

## Instalação

### macOS / Linux

```sh
curl -fsSL https://raw.githubusercontent.com/ViniciusQuatrin/xv/main/install.sh | bash
```

O instalador:

- **macOS**: instala `yt-dlp` e `ffmpeg` via [Homebrew](https://brew.sh) (sem Homebrew, baixa o binário oficial do yt-dlp e avisa sobre o ffmpeg);
- **Linux**: baixa o binário oficial do `yt-dlp` para `~/.local/bin` (os pacotes das distros costumam ficar velhos e quebrar com o X), e instala `ffmpeg` + `wl-clipboard` (Wayland) ou `xclip` (X11) com `apt`/`dnf`/`pacman`/`zypper`/`apk` (pede `sudo`; se falhar, mostra o comando para você rodar);
- copia o `xv` para `~/.local/bin` e adiciona essa pasta ao `PATH` (`~/.zshrc`, `~/.bashrc`, `~/.profile`).

Opções: `XV_NO_DEPS=1` (não mexe nas dependências), `XV_BIN=/outra/pasta`.

Instalação manual: `git clone https://github.com/ViniciusQuatrin/xv && cd xv && ./install.sh` — ou simplesmente copie o arquivo `xv` para qualquer pasta do `PATH`.

### Windows

No PowerShell:

```powershell
irm https://raw.githubusercontent.com/ViniciusQuatrin/xv/main/install.ps1 | iex
```

O instalador roda `winget install yt-dlp.yt-dlp` e `winget install Gyan.FFmpeg`, copia `xv.ps1` para `%LOCALAPPDATA%\xv`, o `xv.cmd` para `%LOCALAPPDATA%\xv\bin` e adiciona essa pasta ao `PATH` do usuário. **Abra um terminal novo** depois de instalar.

O `xv.cmd` chama o `xv.ps1` com `-ExecutionPolicy Bypass`, então não é preciso mudar a política de execução do PowerShell. Funciona no `cmd.exe`, no PowerShell 5.1 e no PowerShell 7.

## Uso

```
xv [-g] <link>
```

| Opção | O que faz |
|-------|-----------|
| *(nenhuma)* | baixa o vídeo em `.mp4` e copia o arquivo |
| `-g` | converte para `.gif` (15 fps, largura máx. 480 px, paleta otimizada) e apaga o `.mp4` |

Onde os arquivos ficam:

| Sistema | Pasta |
|---------|-------|
| macOS | `~/Movies/twitter-videos` |
| Linux | `$XDG_VIDEOS_DIR/twitter-videos` (ou `xdg-user-dir VIDEOS`, senão `~/Videos/twitter-videos`) |
| Windows | `%USERPROFILE%\Videos\twitter-videos` |

Para usar outra pasta: `XV_DIR=/caminho xv <link>` (no Windows: `$env:XV_DIR = 'C:\caminho'`).

### Exemplos

```sh
xv https://x.com/SpaceX/status/1732824684683784516          # mp4
xv -g https://twitter.com/usuario/status/1234567890          # gif
xv "https://x.com/usuario/status/1234567890?s=20&t=abc"      # links com ? e & → use aspas
```

Se o post tiver mais de um vídeo, todos são baixados e todos vão para a área de transferência.

### Sobre GIFs

Os "GIFs" do Twitter/X **não são GIFs**: são vídeos `.mp4` curtos e sem áudio. O `xv` sem `-g` baixa esse mp4 (que é menor e com mais qualidade, e a maioria dos apps reproduz em loop). Use `-g` quando precisar de um `.gif` de verdade (ex.: lugares que só aceitam GIF). Atenção: GIF de vídeo longo fica **enorme** (um vídeo de ~1 min pode passar de 70 MB) — prefira `-g` só para trechos curtos.

## Área de transferência: como funciona e limites

- **macOS**: `osascript` (`set the clipboard to POSIX file …`). Cola como arquivo no Finder, WhatsApp, Slack, Mail, Telegram etc. Com vários arquivos usa `NSPasteboard` via JXA.
- **Windows**: `Set-Clipboard -LiteralPath` (PowerShell 5.1) ou `Clipboard.SetFileDropList` (PowerShell 7). É o mesmo formato do "Copiar" do Explorer (`CF_HDROP`): cola como arquivo no Explorer, WhatsApp Desktop, Slack, Teams, Discord…
- **Linux**: não existe um padrão único para "arquivo na área de transferência".
  - Por padrão o `xv` copia como `text/uri-list` (`file:///…`), usando `wl-copy` no Wayland e `xclip` no X11. Isso cola como arquivo no Dolphin (KDE), Thunar, Nemo, PCManFM, Nautilus (versões GTK4, 43+), Telegram Desktop e em vários apps.
  - Gerenciadores de arquivos GTK mais antigos (Nautilus ≤ 42, Caja) só entendem `x-special/gnome-copied-files`. Use `XV_CLIP=gnome xv <link>` (dá para deixar `export XV_CLIP=gnome` no seu `~/.bashrc`).
  - `xclip`/`wl-copy` só oferecem **um formato por vez**, então não dá para agradar todos os apps ao mesmo tempo.
  - **Apps baseados em Chromium/Electron** (Slack, Discord, WhatsApp Web no navegador) no Linux muitas vezes **não** aceitam colar arquivo vindo do clipboard — podem colar só o texto `file:///…` ou nada. Nesses casos arraste o arquivo da pasta `twitter-videos` ou use o botão de anexar.
  - Sem sessão gráfica (SSH, TTY) não há área de transferência: o `xv` baixa o arquivo, mostra o caminho e sai com código 2.

## Solução de problemas

| Problema | O que fazer |
|----------|-------------|
| `falhou ao baixar` | Atualize o yt-dlp: `yt-dlp -U` (binário oficial), `brew upgrade yt-dlp` ou `winget upgrade yt-dlp.yt-dlp`. O X muda a API com frequência. |
| `falhou ao baixar` em post sensível / conta protegida / NSFW | Precisa de login. Rode o yt-dlp com seus cookies, ex.: `yt-dlp --cookies-from-browser firefox <link>` (o `xv` não faz isso automaticamente). |
| `falhou ao converter` | Verifique o ffmpeg: `ffmpeg -version`. |
| `yt-dlp não encontrado` / `ffmpeg não encontrado` | Rode o instalador de novo ou instale manualmente. No Windows, abra um terminal **novo** depois do winget. |
| `xv: command not found` | Abra um terminal novo; confira se `~/.local/bin` (ou `%LOCALAPPDATA%\xv\bin`) está no `PATH`. |
| Linux: `wl-copy não encontrado` / `xclip não encontrado` | `sudo apt install wl-clipboard` (Wayland) ou `sudo apt install xclip` (X11). Equivalentes: `dnf`, `pacman -S`. |
| Linux: cola o texto `file:///…` em vez do arquivo | Limitação do app (veja acima). Tente `XV_CLIP=gnome` no GNOME, ou arraste o arquivo. |
| Windows: link com `&` dá erro (`'t' não é reconhecido…`) | Coloque o link entre aspas. No PowerShell o `&` pode quebrar mesmo com aspas ao chamar um `.cmd`; o download funciona assim mesmo (a parte depois do `?` não importa) — ou apague o `?s=…` do link. |
| macOS: pede permissão de "Automação"/"Acessibilidade" | Permita para o Terminal em Ajustes do Sistema › Privacidade e Segurança. |

## Licença

[MIT](LICENSE) © 2026 Vinícius Quatrin da Silva
