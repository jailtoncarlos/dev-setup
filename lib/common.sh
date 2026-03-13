#!/bin/bash
# lib/common.sh — Funções utilitárias compartilhadas entre os módulos

# ─── Cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Logging ──────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[AVISO]${RESET} $*"; }
error()   { echo -e "${RED}[ERRO]${RESET}  $*" >&2; }
section() { echo -e "\n${BOLD}${BLUE}══ $* ══${RESET}"; }
cmd()     { echo -e "${MAGENTA}[CMD]${RESET}   $*"; }

# Exibe o comando antes de executá-lo
run_cmd() {
    cmd "$*"
    "$@"
}

# ─── Prompt helpers ───────────────────────────────────────────────────────────

# ask <variavel> <mensagem> [default]
ask() {
    local var="$1" msg="$2" default="${3:-}"
    if [ -n "$default" ]; then
        read -rp "$(echo -e "${BOLD}$msg${RESET} [${default}]: ")" value
        value="${value:-$default}"
    else
        read -rp "$(echo -e "${BOLD}$msg${RESET}: ")" value
    fi
    eval "$var=\"$value\""
}

# ask_yn <mensagem> [default: s] — retorna 0 para sim, 1 para não
ask_yn() {
    local msg="$1" default="${2:-s}"
    local opts; [ "$default" = "s" ] && opts="S/n" || opts="s/N"
    read -rp "$(echo -e "${BOLD}$msg${RESET} [${opts}]: ")" yn
    yn="${yn:-$default}"
    [[ "$yn" =~ ^[sSyY] ]]
}

# ─── Utilitários ──────────────────────────────────────────────────────────────
has_cmd() { command -v "$1" &>/dev/null; }

# Adiciona bloco ao arquivo apenas se o marcador ainda não estiver presente
append_block_if_missing() {
    local file="$1" marker="$2" block="$3"
    grep -qF "$marker" "$file" 2>/dev/null || echo -e "\n$block" >> "$file"
}

# Detecta o arquivo rc do shell atual
detect_shell_rc() {
    case "$(basename "$SHELL")" in
        zsh)  echo "$HOME/.zshrc" ;;
        *)    echo "$HOME/.bashrc" ;;
    esac
}
