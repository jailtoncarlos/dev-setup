#!/bin/bash
# ssh/setup.sh — Configura chaves SSH e ~/.ssh/config para múltiplas plataformas
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
SSH_AGENT_SCRIPT="$HOME/.add_ssh_keys.sh"

# ─── Garantir diretório SSH ───────────────────────────────────────────────────
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# ─── Cabeçalho do arquivo de config ──────────────────────────────────────────
_init_ssh_config() {
    if [ ! -f "$SSH_CONFIG" ]; then
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
        info "Arquivo $SSH_CONFIG criado."
    fi
}

# ─── Verifica se host já existe no config ────────────────────────────────────
_host_exists() {
    grep -q "^Host $1$" "$SSH_CONFIG" 2>/dev/null
}

# ─── Adiciona entrada no ~/.ssh/config ───────────────────────────────────────
_add_ssh_config_entry() {
    local host="$1"
    local hostname="$2"
    local key_file="$3"
    local comment="$4"

    if _host_exists "$host"; then
        warn "Host '$host' já existe em $SSH_CONFIG. Pulando."
        return
    fi

    cat >> "$SSH_CONFIG" <<EOF

# $comment
Host $host
    HostName $hostname
    User git
    IdentityFile $key_file
EOF
    success "Entrada '$host' adicionada ao $SSH_CONFIG."
}

# ─── Gera par de chaves ───────────────────────────────────────────────────────
_generate_key() {
    local key_path="$1"
    local email="$2"
    local label="$3"

    if [ -f "$key_path" ]; then
        warn "Chave $key_path já existe. Pulando geração."
        return
    fi

    ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
    success "Chave gerada: $key_path"
}

# ─── Exibe chave pública ──────────────────────────────────────────────────────
_show_public_key() {
    local pub_key="$1"
    local platform_name="$2"
    local settings_url="$3"

    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${YELLOW}│ Adicione a chave pública abaixo na plataforma: ${BOLD}$platform_name${RESET}${YELLOW}  │${RESET}"
    echo -e "${YELLOW}│ URL: $settings_url${RESET}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────────┘${RESET}"
    cat "$pub_key"
    echo ""
}

# ─── Instala script de ssh-agent ─────────────────────────────────────────────
_install_agent_script() {
    cp "$SCRIPT_DIR/templates/add_ssh_keys.sh" "$SSH_AGENT_SCRIPT"
    chmod +x "$SSH_AGENT_SCRIPT"
    success "Script de ssh-agent instalado em $SSH_AGENT_SCRIPT"
}

# ─── Plataformas pré-definidas ────────────────────────────────────────────────
PLATFORMS=()

_add_platform() {
    # Formato: "nome|host|settings_url|key_suffix_default"
    PLATFORMS+=("$1")
}

_load_default_platforms() {
    _add_platform "GitHub|github.com|https://github.com/settings/keys|github"
    _add_platform "GitLab IFRN|gitlab.ifrn.edu.br|https://gitlab.ifrn.edu.br/-/profile/keys|gitlab_ifrn"
    _add_platform "GitLab LAIS|git.lais.huol.ufrn.br|https://git.lais.huol.ufrn.br/-/profile/keys|gitlab_lais"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    section "Configuração de SSH"

    _init_ssh_config
    _load_default_platforms

    # Permite adicionar plataformas extras
    while ask_yn "Deseja adicionar uma plataforma personalizada?"; do
        ask custom_name  "Nome da plataforma (ex: GitLab Empresa)"
        ask custom_host  "Host (ex: gitlab.empresa.com.br)"
        ask custom_url   "URL de configuração de chaves SSH"
        ask custom_suffix "Sufixo da chave (ex: empresa) — arquivo será id_ed25519_<sufixo>"
        _add_platform "$custom_name|$custom_host|$custom_url|$custom_suffix"
        info "Plataforma '$custom_name' adicionada."
    done

    echo ""
    info "Plataformas que serão configuradas:"
    for p in "${PLATFORMS[@]}"; do
        IFS='|' read -r name host url suffix <<< "$p"
        echo "  • $name ($host)"
    done
    echo ""

    ask global_git_name "Seu nome completo (para commits)" "$(git config --global user.name 2>/dev/null || echo '')"

    for p in "${PLATFORMS[@]}"; do
        IFS='|' read -r name host url suffix <<< "$p"

        section "Plataforma: $name"
        ask email "E-mail cadastrado em $name"

        key_path="$SSH_DIR/id_ed25519_${suffix}"

        _generate_key "$key_path" "$email" "$name"
        _add_ssh_config_entry "$host" "$host" "$key_path" "$name"
        _show_public_key "${key_path}.pub" "$name" "$url"

        read -rp "Pressione ENTER após adicionar a chave em $name para continuar..."
    done

    section "Instalando script de ssh-agent"
    _install_agent_script

    success "Configuração SSH concluída!"
    info "Lembre de adicionar ao seu ~/.bashrc ou ~/.zshrc:"
    echo '  [ -f "$HOME/.add_ssh_keys.sh" ] && source "$HOME/.add_ssh_keys.sh"'
}

main "$@"
