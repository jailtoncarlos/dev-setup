# dev-setup

Scripts para configuração rápida de ambiente de desenvolvimento em uma nova máquina Linux/WSL.

## O que faz

| Módulo | O que configura |
|---|---|
| **ssh** | Gera chaves SSH (`ed25519`) e configura `~/.ssh/config` para múltiplas plataformas |
| **git** | Configura `~/.gitconfig` com identidade global e perfis por diretório (`includeIf`) |
| **workspace** | Cria estrutura de diretórios de trabalho (`~/workspace/...`) |
| **shell** | Configura `~/.bashrc` / `~/.zshrc` com ssh-agent, NVM, PATH extras e aliases |
| **tools/nvm** | Instala o [NVM](https://github.com/nvm-sh/nvm) e uma versão do Node.js |

## Como usar

```bash
git clone https://github.com/jailtoncarlos/dev-setup.git ~/dev-setup
cd ~/dev-setup
bash setup.sh
```

O menu interativo permite rodar **tudo de uma vez** ou **módulo por módulo**.

## Adicionando novos módulos

1. Crie uma pasta para o módulo (ex: `docker/`)
2. Crie o script `docker/setup.sh` usando `lib/common.sh` para logs e prompts
3. Registre o módulo no array `MODULES` em `setup.sh`:

```bash
MODULES=(
    ...
    "docker|Instalar Docker|docker/setup.sh"
)
```

## Estrutura

```
dev-setup/
├── setup.sh              # Entry point interativo
├── lib/
│   └── common.sh         # Funções compartilhadas (log, prompt, helpers)
├── ssh/
│   ├── setup.sh
│   └── templates/
│       └── add_ssh_keys.sh
├── git/
│   └── setup.sh
├── shell/
│   └── setup.sh
├── workspace/
│   └── setup.sh
└── tools/
    └── nvm.sh
```

## Requisitos

- Linux ou WSL2
- `bash` >= 4
- `git`, `ssh-keygen`, `curl`
