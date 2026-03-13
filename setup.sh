#!/bin/bash
# setup.sh — Entry point interativo do dev-setup
# Executa módulos de configuração do ambiente de desenvolvimento
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ─── Módulos disponíveis ──────────────────────────────────────────────────────
# Formato: "id|label|script"
MODULES=(
    "ssh|Chaves SSH e ~/.ssh/config|ssh/setup.sh"
    "git|Configuração do Git (~/.gitconfig)|git/setup.sh"
    "workspace|Estrutura de diretórios de trabalho|workspace/setup.sh"
    "shell|Configuração do shell (.bashrc/.zshrc)|shell/setup.sh"
    "nvm|Instalar NVM (Node Version Manager)|tools/nvm.sh"
)

# ─── Menu ─────────────────────────────────────────────────────────────────────
show_menu() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║         dev-setup — Menu Principal       ║${RESET}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD}0)${RESET} Executar tudo (setup completo)"
    echo ""
    local i=1
    for m in "${MODULES[@]}"; do
        IFS='|' read -r id label script <<< "$m"
        printf "  ${BOLD}%d)${RESET} %s\n" "$i" "$label"
        ((i++))
    done
    echo ""
    echo -e "  ${BOLD}q)${RESET} Sair"
    echo ""
}

run_module() {
    local script="$SCRIPT_DIR/$1"
    if [ ! -f "$script" ]; then
        error "Script não encontrado: $script"
        return 1
    fi
    chmod +x "$script"
    bash "$script"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    while true; do
        show_menu
        read -rp "$(echo -e "${BOLD}Escolha uma opção: ${RESET}")" choice

        case "$choice" in
            0)
                section "Setup completo"
                for m in "${MODULES[@]}"; do
                    IFS='|' read -r id label script <<< "$m"
                    if ask_yn "Executar: $label?"; then
                        run_module "$script"
                    fi
                done
                success "Setup completo finalizado!"
                break
                ;;
            q|Q)
                info "Saindo."
                exit 0
                ;;
            *)
                # Seleção por número
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#MODULES[@]}" ]; then
                    idx=$((choice - 1))
                    IFS='|' read -r id label script <<< "${MODULES[$idx]}"
                    section "$label"
                    run_module "$script"
                    echo ""
                    read -rp "Pressione ENTER para voltar ao menu..."
                else
                    warn "Opção inválida: $choice"
                fi
                ;;
        esac
    done
}

main "$@"
