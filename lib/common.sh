#!/bin/bash
# lib/common.sh — Funções utilitárias compartilhadas entre os módulos

# ─── Cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Logging ──────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[AVISO]${RESET} $*"; }
error()   { echo -e "${RED}[ERRO]${RESET}  $*" >&2; }
section() { echo -e "\n${BOLD}${BLUE}══ $* ══${RESET}"; }

# ─── Prompt helpers ───────────────────────────────────────────────────────────

# ask <variavel> <mensagem> [default]
# Lê input do usuário. Se vazio, usa o default.
ask() {
    local var="$1"
    local msg="$2"
    local default="$3"

    if [ -n "$default" ]; then
        read -rp "$(echo -e "${BOLD}$msg${RESET} [${default}]: ")" value
        value="${value:-$default}"
    else
        read -rp "$(echo -e "${BOLD}$msg${RESET}: ")" value
    fi
    eval "$var=\"$value\""
}

# ask_yn <mensagem> [default: s]
# Retorna 0 para sim, 1 para não
ask_yn() {
    local msg="$1"
    local default="${2:-s}"
    local opts="s/n"
    [ "$default" = "n" ] && opts="s/N"
    [ "$default" = "s" ] && opts="S/n"

    read -rp "$(echo -e "${BOLD}$msg${RESET} [${opts}]: ")" yn
    yn="${yn:-$default}"
    [[ "$yn" =~ ^[sSyY] ]]
}

# ─── Utilitários ──────────────────────────────────────────────────────────────

# Verifica se um comando existe
has_cmd() { command -v "$1" &>/dev/null; }

# Adiciona linha ao arquivo apenas se ainda não estiver presente
append_if_missing() {
    local file="$1"
    local line="$2"
    grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Adiciona bloco ao arquivo se o marcador não existir
append_block_if_missing() {
    local file="$1"
    local marker="$2"
    local block="$3"

    if ! grep -qF "$marker" "$file" 2>/dev/null; then
        echo -e "\n$block" >> "$file"
    fi
}

# Detecta o shell rc file do usuário
detect_shell_rc() {
    local shell_name
    shell_name=$(basename "$SHELL")
    case "$shell_name" in
        zsh)  echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        *)    echo "$HOME/.bashrc" ;;
    esac
}
