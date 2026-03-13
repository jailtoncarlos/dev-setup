#!/bin/bash
# git/setup.sh — Configura ~/.gitconfig com identidade global e perfis por diretório
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

GITCONFIG="$HOME/.gitconfig"

# ─── Helpers ──────────────────────────────────────────────────────────────────

_set_global() {
    git config --global "$1" "$2"
}

_gitconfig_file_for() {
    echo "$HOME/.gitconfig-$1"
}

_create_org_gitconfig() {
    local suffix="$1"
    local name="$2"
    local email="$3"
    local file
    file=$(_gitconfig_file_for "$suffix")

    cat > "$file" <<EOF
[user]
	name = $name
	email = $email
EOF
    success "Criado: $file"
}

_add_include_if() {
    local dir="$1"
    local suffix="$2"
    local marker="includeIf \"gitdir:$dir\""

    if grep -qF "$marker" "$GITCONFIG" 2>/dev/null; then
        warn "includeIf para '$dir' já existe. Pulando."
        return
    fi

    cat >> "$GITCONFIG" <<EOF

[includeIf "gitdir:$dir"]
	path = ~/.gitconfig-$suffix
EOF
    success "includeIf adicionado para $dir → ~/.gitconfig-$suffix"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    section "Configuração do Git"

    # Identidade global (padrão — geralmente GitHub)
    ask global_name  "Seu nome completo" "$(git config --global user.name 2>/dev/null || echo '')"
    ask global_email "E-mail global (padrão/GitHub)" "$(git config --global user.email 2>/dev/null || echo '')"

    _set_global user.name  "$global_name"
    _set_global user.email "$global_email"
    success "Identidade global configurada: $global_name <$global_email>"

    # Configurações recomendadas
    _set_global pull.rebase false
    _set_global core.autocrlf false
    _set_global init.defaultBranch main
    success "Configurações padrão aplicadas (pull.rebase=false, autocrlf=false, defaultBranch=main)"

    # Perfis por diretório (org-specific)
    echo ""
    info "Agora configure perfis específicos por diretório de trabalho."
    info "Exemplo: commits em ~/workspace/ifrn/ usam e-mail do IFRN."
    echo ""

    while ask_yn "Adicionar perfil por diretório?"; do
        ask profile_dir   "Diretório (ex: ~/workspace/ifrn/)"
        ask profile_email "E-mail para commits nesse diretório"
        ask profile_suffix "Sufixo do arquivo de config (ex: ifrn)" "$(basename "$profile_dir" /)"

        # Normaliza ~ para caminho literal com ~/
        normalized_dir="${profile_dir%/}/"
        [[ "$normalized_dir" != ~/* ]] && normalized_dir="~/${normalized_dir#$HOME/}"

        _create_org_gitconfig "$profile_suffix" "$global_name" "$profile_email"
        _add_include_if "$normalized_dir" "$profile_suffix"
    done

    success "Configuração do Git concluída!"
}

main "$@"
