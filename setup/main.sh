#!/bin/bash
# setup/main.sh — Configuração completa do ambiente de desenvolvimento
#
# Abordagem org-cêntrica: o dev informa suas organizações (empresa, instituição,
# cliente, etc.) e o script configura tudo a partir delas:
#   - Chave SSH dedicada por org  →  ~/.ssh/id_ed25519_<org>
#   - Host mapeado no SSH config  →  ~/.ssh/config
#   - Perfil Git por org          →  ~/.gitconfig-<org> + includeIf
#   - Diretório de trabalho       →  <workspace_base>/<org>/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/orgs.sh"

# ─── Configura uma organização completa ───────────────────────────────────────
setup_org() {
    local org="$1"
    local host="$2"
    local email="$3"
    local workspace_base="$4"
    local git_name="$5"

    local key_path workspace_dir gitconfig_file
    key_path=$(org_ssh_key "$org")
    workspace_dir=$(org_workspace_dir "$org" "$workspace_base")
    gitconfig_file=$(org_gitconfig_file "$org")

    section "Configurando org: $org"

    # ── Chave SSH ──────────────────────────────────────────────────────────
    if [ -f "$key_path" ]; then
        warn "Chave já existe: $key_path — pulando geração."
    else
        info "Gerando chave SSH..."
        run_cmd ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
        success "Chave gerada: $key_path"
    fi

    # ── ~/.ssh/config ─────────────────────────────────────────────────────
    if grep -q "^Host ${host}$" "$HOME/.ssh/config" 2>/dev/null; then
        warn "Host '$host' já existe em ~/.ssh/config — pulando."
    else
        info "Adicionando '$host' ao ~/.ssh/config..."
        cat >> "$HOME/.ssh/config" <<EOF

# $org
Host $host
    HostName $host
    User git
    IdentityFile $key_path
EOF
        success "Host '$host' adicionado ao ~/.ssh/config."
    fi

    # ── Diretório de trabalho ─────────────────────────────────────────────
    if [ -d "$workspace_dir" ]; then
        warn "Diretório já existe: $workspace_dir — pulando."
    else
        run_cmd mkdir -p "$workspace_dir"
        success "Diretório criado: $workspace_dir"
    fi

    # ── Perfil Git ────────────────────────────────────────────────────────
    if [ -f "$gitconfig_file" ]; then
        warn "Perfil Git já existe: $gitconfig_file — pulando."
    else
        info "Criando perfil Git: $gitconfig_file..."
        cat > "$gitconfig_file" <<EOF
[user]
	name = $git_name
	email = $email
EOF
        success "Perfil Git criado: $gitconfig_file"
    fi

    # ── includeIf no ~/.gitconfig ─────────────────────────────────────────
    local normalized_dir="${workspace_dir%/}/"
    local marker="includeIf \"gitdir:${normalized_dir}\""
    if grep -qF "$marker" "$HOME/.gitconfig" 2>/dev/null; then
        warn "includeIf para '$org' já existe em ~/.gitconfig — pulando."
    else
        info "Adicionando includeIf para '$org' ao ~/.gitconfig..."
        cat >> "$HOME/.gitconfig" <<EOF

[includeIf "gitdir:${normalized_dir}"]
	path = $gitconfig_file
EOF
        success "includeIf adicionado: $normalized_dir → $gitconfig_file"
    fi

    # ── Exibir chave pública ───────────────────────────────────────────────
    echo ""
    echo -e "${YELLOW}┌────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${YELLOW}│ Adicione esta chave pública em: https://$host              ${RESET}"
    echo -e "${YELLOW}└────────────────────────────────────────────────────────────┘${RESET}"
    cat "${key_path}.pub"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    section "Preparação do ambiente de desenvolvimento"

    # ── Garantir ~/.ssh ───────────────────────────────────────────────────
    run_cmd mkdir -p "$HOME/.ssh"
    run_cmd chmod 700 "$HOME/.ssh"
    [ ! -f "$HOME/.ssh/config" ] && touch "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"

    # ── Identidade global ─────────────────────────────────────────────────
    echo ""
    info "Identidade global (usada em repositórios fora de qualquer org configurada)."
    ask git_name  "Seu nome completo" "$(git config --global user.name  2>/dev/null || echo '')"
    ask git_email "E-mail padrão (ex: conta GitHub pessoal)" "$(git config --global user.email 2>/dev/null || echo '')"

    run_cmd git config --global user.name  "$git_name"
    run_cmd git config --global user.email "$git_email"
    run_cmd git config --global pull.rebase false
    run_cmd git config --global core.autocrlf false
    run_cmd git config --global init.defaultBranch main
    success "Identidade global configurada."

    # ── Diretório base ────────────────────────────────────────────────────
    echo ""
    local default_base
    default_base=$(detect_workspace_base)
    ask workspace_base "Diretório base onde ficam os projetos" "${default_base:-$HOME/workspace}"
    workspace_base="${workspace_base/#\~/$HOME}"

    if [ ! -d "$workspace_base" ]; then
        run_cmd mkdir -p "$workspace_base"
        success "Diretório base criado: $workspace_base"
    fi

    # ── Organizações ──────────────────────────────────────────────────────
    echo ""
    info "Informe suas organizações (empresas, instituições, clientes, etc.)."
    info "Para cada uma serão criados: chave SSH, perfil Git e diretório de trabalho."
    info "O nome da org vira prefixo da chave e nome do subdiretório."
    info "  Exemplo: 'ifrn' → ~/.ssh/id_ed25519_ifrn, $workspace_base/ifrn/"
    echo ""

    local orgs_count=0

    while ask_yn "Adicionar organização?"; do
        echo ""
        ask org_name  "Nome da org (ex: ifrn, empresa, lais, pessoal)"
        ask org_host  "Host Git da org (ex: gitlab.ifrn.edu.br, github.com)"
        ask org_email "E-mail para commits nessa org"
        echo ""

        setup_org "$org_name" "$org_host" "$org_email" "$workspace_base" "$git_name"

        read -rp "$(echo -e "${BOLD}Pressione ENTER após adicionar a chave pública em $org_host...${RESET}")"

        info "Testando autenticação SSH com $org_host..."
        run_cmd ssh -T "git@${org_host}" || true

        echo ""
        ((orgs_count++))
    done

    [ "$orgs_count" -eq 0 ] && warn "Nenhuma organização configurada."

    # ── Script ssh-agent ──────────────────────────────────────────────────
    echo ""
    local agent_script="$HOME/.add_ssh_keys.sh"
    local agent_template="$SCRIPT_DIR/ssh/templates/add_ssh_keys.sh"

    if [ -f "$agent_template" ]; then
        if [ ! -f "$agent_script" ]; then
            run_cmd cp "$agent_template" "$agent_script"
            run_cmd chmod +x "$agent_script"
            success "Script de ssh-agent instalado: $agent_script"
        else
            warn "Script de ssh-agent já existe: $agent_script — pulando."
        fi
    fi

    # ── Shell ─────────────────────────────────────────────────────────────
    echo ""
    if ask_yn "Configurar shell (.bashrc/.zshrc)?"; then
        bash "$SCRIPT_DIR/shell/setup.sh"
    fi

    # ── NVM ───────────────────────────────────────────────────────────────
    echo ""
    if ask_yn "Instalar NVM (Node Version Manager)?"; then
        bash "$SCRIPT_DIR/tools/nvm.sh"
    fi

    echo ""
    success "Configuração do ambiente concluída!"
    [ "$orgs_count" -gt 0 ] && info "Próximo passo: use a opção '2) Clonar projeto' para clonar seus repositórios."
}

main "$@"
