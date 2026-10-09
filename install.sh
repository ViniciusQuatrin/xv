#!/usr/bin/env bash
# Instalador do xv para macOS e Linux.
#   curl -fsSL https://raw.githubusercontent.com/ViniciusQuatrin/xv/main/install.sh | bash
# Variáveis opcionais:
#   XV_BIN=~/.local/bin   pasta de instalação
#   XV_NO_DEPS=1          não tenta instalar dependências (yt-dlp, ffmpeg, clipboard)
set -eu

REPO_RAW="${XV_REPO_RAW:-https://raw.githubusercontent.com/ViniciusQuatrin/xv/main}"
BIN="${XV_BIN:-$HOME/.local/bin}"
OS="$(uname -s)"
ARCH="$(uname -m)"

info() { printf '==> %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

download() { # url destino
  if have curl; then curl -fsSL "$1" -o "$2"
  elif have wget; then wget -qO "$2" "$1"
  else warn "preciso de curl ou wget"; return 1; fi
}

SUDO=""
if [ "$(id -u)" -ne 0 ] && have sudo; then SUDO="sudo"; fi

pm_install() { # pacotes... (Linux) — tenta instalar; se falhar, mostra o comando
  local cmd=""
  if have apt-get; then cmd="apt-get install -y $*"
  elif have dnf; then cmd="dnf install -y $*"
  elif have pacman; then cmd="pacman -S --needed --noconfirm $*"
  elif have zypper; then cmd="zypper install -y $*"
  elif have apk; then cmd="apk add $*"
  else warn "gerenciador de pacotes não reconhecido; instale manualmente: $*"; return 1; fi
  info "instalando: $* ($cmd)"
  # shellcheck disable=SC2086
  if ! $SUDO $cmd </dev/tty; then
    warn "não consegui instalar. Rode manualmente: sudo $cmd"
    return 1
  fi
}

install_ytdlp_standalone() {
  local asset
  case "$OS-$ARCH" in
    Linux-x86_64|Linux-amd64) asset="yt-dlp_linux" ;;
    Linux-aarch64|Linux-arm64) asset="yt-dlp_linux_aarch64" ;;
    Darwin-*) asset="yt-dlp_macos" ;;
    *) asset="yt-dlp" ;; # zipapp, precisa de python3
  esac
  info "baixando yt-dlp ($asset) para $BIN/yt-dlp"
  download "https://github.com/yt-dlp/yt-dlp/releases/latest/download/$asset" "$BIN/yt-dlp"
  chmod +x "$BIN/yt-dlp"
}

mkdir -p "$BIN"

# --- dependências -----------------------------------------------------------
if [ "${XV_NO_DEPS:-0}" != 1 ]; then
  if [ "$OS" = "Darwin" ]; then
    if have brew; then
      for p in yt-dlp ffmpeg; do
        have "$p" || { info "brew install $p"; brew install "$p" || warn "falhou: brew install $p"; }
      done
    else
      have yt-dlp || install_ytdlp_standalone || warn "falhou ao baixar yt-dlp"
      have ffmpeg || warn "ffmpeg não encontrado. Instale o Homebrew (https://brew.sh) e rode: brew install ffmpeg"
    fi
  else
    # yt-dlp: o binário oficial é sempre atual (pacotes de distro costumam quebrar com o X)
    have yt-dlp || install_ytdlp_standalone || warn "falhou ao baixar yt-dlp"
    have ffmpeg || pm_install ffmpeg || true
    if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
      have wl-copy || pm_install wl-clipboard || true
    else
      have xclip || pm_install xclip || true
    fi
  fi
fi

# --- xv -----------------------------------------------------------------------
SRC_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/xv" ]; then
  info "copiando $SRC_DIR/xv para $BIN/xv"
  cp "$SRC_DIR/xv" "$BIN/xv"
else
  info "baixando xv para $BIN/xv"
  download "$REPO_RAW/xv" "$BIN/xv"
fi
chmod +x "$BIN/xv"

# --- PATH ---------------------------------------------------------------------
case ":$PATH:" in
  *":$BIN:"*) ;;
  *)
    LINE="export PATH=\"$BIN:\$PATH\""
    for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
      # .zshrc só no macOS ou se já existir; .bashrc/.profile se existirem (ou no Linux)
      if [ -f "$rc" ] || { [ "$rc" = "$HOME/.zshrc" ] && [ "$OS" = "Darwin" ]; } || { [ "$rc" = "$HOME/.bashrc" ] && [ "$OS" != "Darwin" ]; }; then
        if ! grep -qsF "# xv PATH" "$rc"; then
          printf '\n%s # xv PATH\n' "$LINE" >>"$rc"
          info "adicionado $BIN ao PATH em $rc"
        fi
      fi
    done
    warn "abra um novo terminal (ou rode: $LINE) para usar o xv"
    ;;
esac

# --- resumo -------------------------------------------------------------------
echo
for d in yt-dlp ffmpeg; do have "$d" || [ -x "$BIN/$d" ] || warn "$d ainda não está instalado"; done
if [ "$OS" != "Darwin" ] && ! have wl-copy && ! have xclip; then
  warn "instale wl-clipboard (Wayland) ou xclip (X11) para copiar o arquivo"
fi
info "pronto! uso: xv [-g] <link do X/Twitter>"
