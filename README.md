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
| **docs** | Converte Markdown → HTML/PDF com suporte a diagramas Mermaid via pandoc |

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
├── tools/
│   └── nvm.sh
└── docs/
    ├── export_doc.py         # Converte .md → HTML ou PDF
    ├── pandoc_mermaid.lua    # Filtro Lua para diagramas Mermaid
    └── assets/
        ├── doc.css           # CSS padrão
        └── themes/           # Temas alternativos (github, academic, minimal)
```

## docs/export_doc.py

Converte arquivos Markdown para HTML ou PDF via pandoc, com suporte a diagramas Mermaid (`flowchart LR`, `sequenceDiagram`, etc.).

```bash
# HTML simples
python3 docs/export_doc.py README.md

# Com anexos linkados e tema alternativo
python3 docs/export_doc.py docs/DEPLOY.md --theme github

# PDF via Playwright (padrão) — preserva CSS e renderiza Mermaid
python3 docs/export_doc.py docs/DEPLOY.md --format pdf --output build/deploy.pdf

# PDF via wkhtmltopdf — mais leve, sem renderização de Mermaid
python3 docs/export_doc.py docs/DEPLOY.md --format pdf --pdf-engine wkhtmltopdf

# Apenas o documento principal, sem seguir links
python3 docs/export_doc.py docs/DEPLOY.md --no-follow

# Um HTML por arquivo linkado
python3 docs/export_doc.py docs/DEPLOY.md --split --output build/deploy.html
```

### Motores de PDF (`--pdf-engine`)

| Engine | Mermaid | CSS/Layout | Velocidade | Requisito |
|---|---|---|---|---|
| `playwright` (padrão) | Renderiza | Completo | Mais lento | `pip install playwright && playwright install chromium` |
| `wkhtmltopdf` | **Não renderiza** | Parcial | Mais rápido | `wkhtmltopdf` instalado no sistema |

Use `playwright` quando o documento tiver diagramas Mermaid ou layout visual elaborado.
Use `wkhtmltopdf` para documentos simples, sem diagramas.

**Requisitos gerais:** `pandoc` no PATH (ou `pip install pypandoc-binary`).

```bash
pip install -r requirements.txt
playwright install chromium  # apenas se usar --pdf-engine playwright
```

## Requisitos

- Linux ou WSL2
- `bash` >= 4
- `git`, `ssh-keygen`, `curl`
