#!/bin/bash
# ~/.add_ssh_keys.sh
# Inicia o ssh-agent (ou reutiliza um existente) e carrega todas as chaves id_ed25519_*
# Gerado automaticamente por dev-setup — edite com cuidado.

SSH_ENV="$HOME/.ssh/agent.env"

start_agent() {
    echo "[INFO] Iniciando novo ssh-agent..."
    (umask 066; ssh-agent > "$SSH_ENV")
    source "$SSH_ENV"
}

if [ -f "$SSH_ENV" ]; then
    source "$SSH_ENV" > /dev/null
    if ! ps -p "$SSH_AGENT_PID" > /dev/null 2>&1; then
        start_agent
    elif [ ! -S "$SSH_AUTH_SOCK" ]; then
        echo "[AVISO] Socket do ssh-agent inválido. Reiniciando agente..."
        start_agent
    fi
else
    start_agent
fi

ssh-add -l > /dev/null 2>&1
if [ $? -eq 2 ]; then
    echo "[AVISO] Não foi possível conectar ao ssh-agent. Reiniciando..."
    start_agent
fi

for key in "$HOME"/.ssh/id_ed25519_*; do
    [ -f "$key" ]      || continue
    [[ "$key" == *.pub ]] && continue

    fingerprint=$(ssh-keygen -lf "$key" | awk '{print $2}')
    if ! ssh-add -l | grep -q "$fingerprint"; then
        echo "[INFO] Adicionando chave: $key"
        ssh-add "$key"
    else
        echo "[INFO] Chave já carregada: $key"
    fi
done
