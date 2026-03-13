#!/bin/bash
# workspace/setup.sh — Cria estrutura de diretórios de trabalho
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Diretórios padrão sugeridos
DEFAULT_DIRS=(
    "$HOME/workspace/ifrn"
    "$HOME/workspace/lais"
    "$HOME/workspace/prisma_roche"
    "$HOME/workspace/pessoal"
)

main() {
    section "Estrutura de diretórios de trabalho"

    info "Diretórios padrão que serão criados:"
    for d in "${DEFAULT_DIRS[@]}"; do
        echo "  • $d"
    done
    echo ""

    if ask_yn "Criar os diretórios padrão acima?"; then
        for d in "${DEFAULT_DIRS[@]}"; do
            if [ -d "$d" ]; then
                warn "$d já existe. Pulando."
            else
                mkdir -p "$d"
                success "Criado: $d"
            fi
        done
    fi

    # Diretórios extras
    while ask_yn "Adicionar diretório extra?"; do
        ask extra_dir "Caminho do diretório (ex: ~/workspace/empresa)"
        extra_dir="${extra_dir/#\~/$HOME}"
        if [ -d "$extra_dir" ]; then
            warn "$extra_dir já existe. Pulando."
        else
            mkdir -p "$extra_dir"
            success "Criado: $extra_dir"
        fi
    done

    success "Estrutura de diretórios concluída!"
}

main "$@"
