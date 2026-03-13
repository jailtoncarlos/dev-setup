#!/bin/bash
# tools/nvm.sh — Instala o NVM (Node Version Manager)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

NVM_DIR="$HOME/.nvm"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh"

main() {
    section "Instalação do NVM"

    if [ -d "$NVM_DIR" ]; then
        warn "NVM já está instalado em $NVM_DIR. Pulando."
        return
    fi

    if ! has_cmd curl; then
        error "curl não encontrado. Instale com: sudo apt install curl"
        exit 1
    fi

    info "Baixando e instalando NVM..."
    curl -o- "$NVM_INSTALL_URL" | bash
    success "NVM instalado com sucesso."

    info "Carregando NVM na sessão atual..."
    export NVM_DIR="$NVM_DIR"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    ask node_version "Versão do Node.js para instalar (deixe em branco para pular)" ""
    if [ -n "$node_version" ]; then
        nvm install "$node_version"
        nvm use "$node_version"
        nvm alias default "$node_version"
        success "Node.js $node_version instalado e definido como padrão."
    fi
}

main "$@"
