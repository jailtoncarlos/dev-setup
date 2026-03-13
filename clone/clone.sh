#!/bin/bash
# clone/clone.sh — Clona um repositório detectando a org pelo domínio da URL
#
# Fluxo:
#   1. Pede a URL do repositório
#   2. Detecta o host e sugere o nome da org a partir do domínio
#   3. Verifica se a org já está configurada (chave SSH + perfil Git)
#   4. Oferece configurar a org se necessário
#   5. Clona para <workspace_base>/<org>/<projeto>
#   6. Confirma a identidade de commit que será usada
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/orgs.sh"

main() {
    section "Clonar projeto"

    ask repo_url "URL do repositório (SSH ou HTTPS)"
    echo ""

    # ── Detectar host e sugerir org ───────────────────────────────────────
    local host
    host=$(extract_host_from_url "$repo_url")

    if [ -z "$host" ]; then
        error "Não foi possível detectar o host a partir da URL informada."
        exit 1
    fi

    info "Host detectado:  $host"

    local suggested_org
    suggested_org=$(suggest_org_from_host "$host")
    info "Org sugerida:    $suggested_org"
    echo ""

    ask org_name "Confirme o nome da org" "$suggested_org"

    # ── Verificar e configurar org se necessário ──────────────────────────
    if org_is_configured "$org_name"; then
        success "Org '$org_name' já está configurada."
    else
        warn "Org '$org_name' não está completamente configurada (chave SSH ou perfil Git ausente)."
        if ask_yn "Configurar a org '$org_name' agora?"; then
            local git_name workspace_base
            git_name=$(git config --global user.name 2>/dev/null || echo "")
            workspace_base=$(detect_workspace_base)

            ask org_host  "Host Git da org" "$host"
            ask org_email "E-mail para commits nessa org"
            [ -z "$workspace_base" ] && ask workspace_base "Diretório base dos projetos" "$HOME/workspace"
            workspace_base="${workspace_base/#\~/$HOME}"

            # Importa e executa setup_org do módulo de setup
            source "$SCRIPT_DIR/setup/main.sh"
            setup_org "$org_name" "$org_host" "$org_email" "$workspace_base" "$git_name"

            read -rp "$(echo -e "${BOLD}Pressione ENTER após adicionar a chave pública em $org_host...${RESET}")"
            info "Testando autenticação SSH..."
            run_cmd ssh -T "git@${org_host}" || true
            echo ""
        else
            warn "Prosseguindo sem configuração completa — a autenticação pode falhar."
        fi
    fi

    # ── Determinar destino do clone ───────────────────────────────────────
    local workspace_base
    workspace_base=$(detect_workspace_base)
    if [ -z "$workspace_base" ]; then
        ask workspace_base "Diretório base dos projetos" "$HOME/workspace"
        workspace_base="${workspace_base/#\~/$HOME}"
    fi

    local project_name dest_dir clone_dest
    project_name=$(extract_project_from_url "$repo_url")
    dest_dir=$(org_workspace_dir "$org_name" "$workspace_base")
    clone_dest="$dest_dir/$project_name"

    echo ""
    info "Projeto:     $project_name"
    info "Org:         $org_name"
    info "Destino:     $clone_dest"
    echo ""

    if [ -d "$clone_dest" ]; then
        warn "O destino já existe: $clone_dest"
        ask_yn "Continuar mesmo assim?" "n" || { info "Cancelado."; return; }
    fi

    # ── Garantir diretório da org ─────────────────────────────────────────
    if [ ! -d "$dest_dir" ]; then
        run_cmd mkdir -p "$dest_dir"
        success "Diretório criado: $dest_dir"
    fi

    # ── Clonar ────────────────────────────────────────────────────────────
    ask_yn "Confirmar clone em $clone_dest?" || { info "Cancelado."; return; }

    run_cmd git clone "$repo_url" "$clone_dest"
    success "Clone concluído: $clone_dest"

    # ── Confirmar identidade de commit ────────────────────────────────────
    echo ""
    local identity_name identity_email
    identity_name=$(git  -C "$clone_dest" config user.name  2>/dev/null || echo "não detectado")
    identity_email=$(git -C "$clone_dest" config user.email 2>/dev/null || echo "não detectado")

    echo -e "${BOLD}Identidade de commits neste repositório:${RESET}"
    echo "  Nome:  $identity_name"
    echo "  Email: $identity_email"
    echo ""
}

main "$@"
