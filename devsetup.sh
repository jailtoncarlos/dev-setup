#!/usr/bin/env bash
# devsetup.sh — Utilitários para ambiente de desenvolvimento
#
# Menu principal com três contextos:
#   1) Preparar ambiente   — SSH, Git, workspace, shell (org-cêntrico)
#   2) Clonar projeto      — detecta org pelo domínio da URL
#   3) Gerar HTML/PDF      — converte .md via pandoc + Mermaid
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/orgs.sh"

# ─── Painel de estado do ambiente ─────────────────────────────────────────────
_status_line() {
    local label="$1" ok="$2" detail="${3:-}"
    if [ "$ok" = "true" ]; then
        printf "  ${GREEN}[✓]${RESET} %-22s %s\n" "$label" "$detail"
    else
        printf "  ${RED}[✗]${RESET} %-22s ${YELLOW}%s${RESET}\n" "$label" "${detail:-não configurado}"
    fi
}

_show_environment() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║            Estado do ambiente atual                  ║${RESET}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # Git
    local git_name git_email orgs_list
    git_name=$(git config --global user.name  2>/dev/null || echo "")
    git_email=$(git config --global user.email 2>/dev/null || echo "")
    orgs_list=$(list_configured_orgs | paste -sd ', ' -)

    echo -e "  ${BOLD}Git${RESET}"
    _status_line "Nome global"   "$([ -n "$git_name"  ] && echo true || echo false)" "$git_name"
    _status_line "Email global"  "$([ -n "$git_email" ] && echo true || echo false)" "$git_email"
    _status_line "Perfis de org" "$([ -n "$orgs_list" ] && echo true || echo false)" "${orgs_list:-nenhum}"

    echo ""

    # SSH
    local ssh_config_count=0
    [ -f "$HOME/.ssh/config" ] && \
        ssh_config_count=$(grep -c "^Host " "$HOME/.ssh/config" 2>/dev/null || echo 0)

    echo -e "  ${BOLD}SSH${RESET}"
    _status_line "Chaves (id_ed25519_*)" \
        "$([ -n "$orgs_list" ] && echo true || echo false)" \
        "${orgs_list:-nenhuma}"
    _status_line "~/.ssh/config" \
        "$([ "$ssh_config_count" -gt 0 ] && echo true || echo false)" \
        "$ssh_config_count host(s) configurado(s)"

    echo ""

    # Shell
    local rc_file shell_ok="false"
    rc_file=$(detect_shell_rc)
    grep -q "add_ssh_keys.sh" "$rc_file" 2>/dev/null && shell_ok="true"

    echo -e "  ${BOLD}Shell${RESET}  ($rc_file)"
    _status_line "ssh-agent automático" "$shell_ok"

    echo ""

    # Workspace
    local ws_base ws_ok="false" ws_detail="não encontrado"
    ws_base=$(detect_workspace_base)
    if [ -n "$ws_base" ]; then
        ws_ok="true"
        ws_detail="$ws_base  ($(ls "$ws_base" 2>/dev/null | paste -sd ', ' -))"
    fi

    echo -e "  ${BOLD}Workspace${RESET}"
    _status_line "Diretório base" "$ws_ok" "$ws_detail"

    echo ""
}

# ─── Opção 3: Gerar HTML/PDF ───────────────────────────────────────────────────
_run_export_doc() {
    section "Gerar HTML/PDF de arquivo Markdown"

    local export_script="$SCRIPT_DIR/docs/export_doc.py"

    if [ ! -f "$export_script" ]; then
        error "Script não encontrado: $export_script"
        return 1
    fi

    if ! has_cmd python3; then
        error "python3 não encontrado. Instale o Python 3 para usar esta opção."
        return 1
    fi

    ask input_file "Caminho do arquivo Markdown (.md)"
    input_file="${input_file/#\~/$HOME}"

    if [ ! -f "$input_file" ]; then
        error "Arquivo não encontrado: $input_file"
        return 1
    fi

    echo ""
    echo "  Formato de saída:"
    echo "    1) HTML — arquivo auto-contido, com diagramas Mermaid (padrão)"
    echo "    2) PDF"
    read -rp "$(echo -e "  ${BOLD}Escolha [1/2]${RESET}: ")" fmt_choice
    fmt_choice="${fmt_choice:-1}"

    local format="html"
    local extra_args=()

    if [ "$fmt_choice" = "2" ]; then
        format="pdf"
        echo ""
        echo "  Motor de PDF:"
        echo "    1) playwright   — preserva CSS e renderiza diagramas Mermaid (padrão)"
        echo "    2) wkhtmltopdf  — mais leve, sem renderização de diagramas"
        read -rp "$(echo -e "  ${BOLD}Escolha [1/2]${RESET}: ")" engine_choice
        engine_choice="${engine_choice:-1}"
        [ "$engine_choice" = "2" ] && extra_args+=("--pdf-engine" "wkhtmltopdf")
    fi

    echo ""
    ask output_file "Arquivo de saída (deixe em branco para usar o padrão)" ""
    [ -n "$output_file" ] && extra_args+=("--output" "${output_file/#\~/$HOME}")

    echo ""
    run_cmd python3 "$export_script" "$input_file" --format "$format" "${extra_args[@]}"
}

# ─── Menu ──────────────────────────────────────────────────────────────────────
_show_menu() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║               dev-setup — Menu Principal             ║${RESET}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD}1)${RESET} Preparar ambiente"
    echo -e "     ${CYAN}Configura SSH, Git, workspace e shell para múltiplos repositórios${RESET}"
    echo ""
    echo -e "  ${BOLD}2)${RESET} Clonar projeto"
    echo -e "     ${CYAN}Detecta a org pelo domínio da URL e clona no diretório correto${RESET}"
    echo ""
    echo -e "  ${BOLD}3)${RESET} Gerar HTML/PDF de arquivo .md"
    echo -e "     ${CYAN}Converte Markdown com suporte a diagramas Mermaid${RESET}"
    echo ""
    echo -e "  ${BOLD}q)${RESET} Sair"
    echo ""
}

# ─── Entry point ──────────────────────────────────────────────────────────────
main() {
    _show_environment

    while true; do
        _show_menu
        read -rp "$(echo -e "${BOLD}Escolha uma opção: ${RESET}")" choice

        case "$choice" in
            1) bash "$SCRIPT_DIR/setup/main.sh" ;;
            2) bash "$SCRIPT_DIR/clone/clone.sh" ;;
            3) _run_export_doc ;;
            q|Q) info "Até logo."; exit 0 ;;
            *) warn "Opção inválida: $choice" ;;
        esac

        echo ""
        read -rp "$(echo -e "${BOLD}Pressione ENTER para voltar ao menu...${RESET}")"
        _show_environment
    done
}

main "$@"
