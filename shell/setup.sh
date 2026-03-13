#!/bin/bash
# shell/setup.sh — Configura ~/.bashrc / ~/.zshrc com ssh-agent, PATH e ferramentas
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

main() {
    section "Configuração do Shell"

    local rc_file
    rc_file=$(detect_shell_rc)
    info "Shell RC detectado: $rc_file"

    # ── SSH Agent ────────────────────────────────────────────────────────────
    if ask_yn "Adicionar carregamento automático do ssh-agent ao $rc_file?"; then
        append_block_if_missing "$rc_file" "add_ssh_keys.sh" \
'# SSH Agent — carrega chaves automaticamente
[ -f "$HOME/.add_ssh_keys.sh" ] && source "$HOME/.add_ssh_keys.sh"'
        success "SSH agent configurado no $rc_file."
    fi

    # ── NVM ──────────────────────────────────────────────────────────────────
    if ask_yn "Adicionar configuração do NVM ao $rc_file?"; then
        append_block_if_missing "$rc_file" "NVM_DIR" \
'# NVM — Node Version Manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
        success "NVM configurado no $rc_file."
    fi

    # ── PATH extras ──────────────────────────────────────────────────────────
    if ask_yn "Adicionar ~/.local/bin ao PATH?"; then
        append_block_if_missing "$rc_file" '~/.local/bin' \
'# Local binaries
export PATH="$HOME/.local/bin:$PATH"'
        success "~/.local/bin adicionado ao PATH."
    fi

    # ── Entradas PATH/alias personalizadas ───────────────────────────────────
    while ask_yn "Adicionar entrada PATH ou alias personalizado?"; do
        echo "Tipo:"
        echo "  1) PATH (ex: ~/workspace/sdocker)"
        echo "  2) alias (ex: sdocker=/home/user/workspace/sdocker/service.sh)"
        read -rp "Escolha [1/2]: " tipo

        case "$tipo" in
            1)
                ask path_entry "Caminho a adicionar ao PATH"
                path_entry="${path_entry/#\~/$HOME}"
                append_block_if_missing "$rc_file" "$path_entry" \
"export PATH=\"\$PATH:$path_entry\""
                success "PATH adicionado: $path_entry"
                ;;
            2)
                ask alias_name "Nome do alias"
                ask alias_cmd  "Comando do alias"
                append_block_if_missing "$rc_file" "alias $alias_name=" \
"alias $alias_name=\"$alias_cmd\""
                success "Alias adicionado: $alias_name"
                ;;
            *)
                warn "Opção inválida. Pulando."
                ;;
        esac
    done

    success "Configuração do shell concluída!"
    warn "Execute 'source $rc_file' ou abra um novo terminal para aplicar as mudanças."
}

main "$@"
