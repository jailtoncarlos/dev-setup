#!/bin/bash
# lib/orgs.sh — Funções de gerenciamento de organizações
#
# O conceito de "org" é o elemento central que conecta todos os módulos:
#   org name  →  ~/.ssh/id_ed25519_<org>
#             →  ~/.ssh/config (Host <git-host>)
#             →  ~/.gitconfig-<org>  (includeIf)
#             →  ~/workspace/<base>/<org>/

# ─── Extração de host a partir de URL ────────────────────────────────────────
# Suporta:
#   git@gitlab.ifrn.edu.br:cosinf/suap.git
#   https://github.com/Prisma-Consultoria/siscan-rpa
extract_host_from_url() {
    local url="$1"
    if [[ "$url" =~ ^git@ ]]; then
        echo "$url" | sed 's/git@\([^:]*\):.*/\1/'
    elif [[ "$url" =~ ^https?:// ]]; then
        echo "$url" | sed 's|https\?://\([^/]*\).*|\1|'
    else
        echo ""
    fi
}

# ─── Sugestão de nome de org a partir do host ─────────────────────────────────
# github.com              → github
# gitlab.ifrn.edu.br      → ifrn
# git.lais.huol.ufrn.br   → lais
# gitlab.empresa.com.br   → empresa
suggest_org_from_host() {
    local host="$1"
    # Remove prefixos comuns de plataformas git, depois pega o primeiro segmento
    echo "$host" \
        | sed 's/^\(git\.\|gitlab\.\|github\.\|bitbucket\.\)//' \
        | cut -d. -f1
}

# ─── Nome do projeto a partir da URL ─────────────────────────────────────────
extract_project_from_url() {
    basename "$1" .git
}

# ─── Caminhos derivados do nome da org ───────────────────────────────────────
org_ssh_key()        { echo "$HOME/.ssh/id_ed25519_$1"; }
org_gitconfig_file() { echo "$HOME/.gitconfig-$1"; }
org_workspace_dir()  { echo "${2:-$HOME/workspace}/$1"; }

# ─── Lista orgs já configuradas (a partir das chaves SSH existentes) ──────────
list_configured_orgs() {
    for key in "$HOME"/.ssh/id_ed25519_*; do
        [[ "$key" == *.pub ]] && continue
        [ -f "$key" ] || continue
        basename "$key" | sed 's/^id_ed25519_//'
    done
}

# ─── Verifica se uma org está completamente configurada ───────────────────────
org_is_configured() {
    local org="$1"
    [ -f "$(org_ssh_key "$org")" ] && [ -f "$(org_gitconfig_file "$org")" ]
}

# ─── Detecta o diretório base dos workspaces ──────────────────────────────────
detect_workspace_base() {
    [ -d "$HOME/workspace" ] && echo "$HOME/workspace" || echo ""
}
