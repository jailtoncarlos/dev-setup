# dev-setup

Coleção de utilitários para ambiente de desenvolvimento. Cada contexto é independente — use o que precisar.

---

## Índice

- [1. Configuração de ambiente](#1-configuração-de-ambiente)
- [2. Documentação — Markdown para HTML/PDF](#2-documentação--markdown-para-htmlpdf)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Adicionando novos utilitários](#adicionando-novos-utilitários)

---

## 1. Configuração de ambiente

Scripts interativos para configurar uma nova máquina Linux/WSL2 do zero: chaves SSH, identidade Git, estrutura de diretórios e shell.

### Módulos

| Módulo | O que configura |
|---|---|
| **ssh** | Gera chaves SSH (`ed25519`) e configura `~/.ssh/config` para múltiplas plataformas |
| **git** | Configura `~/.gitconfig` com identidade global e perfis por diretório (`includeIf`) |
| **workspace** | Cria estrutura de diretórios de trabalho (`~/workspace/...`) |
| **shell** | Configura `~/.bashrc` / `~/.zshrc` com ssh-agent, NVM, PATH extras e aliases |
| **tools/nvm** | Instala o [NVM](https://github.com/nvm-sh/nvm) e uma versão do Node.js |

### Como usar

```bash
git clone https://github.com/jailtoncarlos/dev-setup.git ~/dev-setup
cd ~/dev-setup
bash setup.sh
```

O menu interativo permite rodar **tudo de uma vez** ou **módulo por módulo**.

### Requisitos

- Linux ou WSL2
- `bash` >= 4
- `git`, `ssh-keygen`, `curl`

---

## 2. Documentação — Markdown para HTML/PDF

Converte arquivos Markdown para HTML ou PDF via pandoc, com suporte a diagramas Mermaid (`flowchart LR`, `sequenceDiagram`, C4, etc.).

### Uso rápido

```bash
# HTML standalone (padrão) — segue links para outros .md e os incorpora como apêndices
python3 docs/export_doc.py docs/DEPLOY.md

# HTML com tema alternativo
python3 docs/export_doc.py docs/DEPLOY.md --theme github

# Apenas o documento principal, sem seguir links
python3 docs/export_doc.py docs/DEPLOY.md --no-follow

# Um HTML por arquivo linkado (mantém links funcionando entre eles)
python3 docs/export_doc.py docs/DEPLOY.md --split --output build/deploy.html

# PDF com renderização de Mermaid (padrão)
python3 docs/export_doc.py docs/DEPLOY.md --format pdf --output build/deploy.pdf

# PDF leve, sem renderização de Mermaid
python3 docs/export_doc.py docs/DEPLOY.md --format pdf --pdf-engine wkhtmltopdf
```

### Motores de PDF (`--pdf-engine`)

| Engine | Diagramas Mermaid | CSS/Layout | Velocidade | Requisito |
|---|---|---|---|---|
| `playwright` (padrão) | Renderiza | Completo | Mais lento | `pip install playwright && playwright install chromium` |
| `wkhtmltopdf` | **Não renderiza** | Parcial | Mais rápido | `wkhtmltopdf` instalado no sistema |

Use `playwright` quando o documento tiver diagramas ou layout visual elaborado.
Use `wkhtmltopdf` para documentos simples, sem diagramas.

### Requisitos

```bash
pip install -r requirements.txt
playwright install chromium  # apenas se usar --pdf-engine playwright (padrão)
```

- `pandoc` no PATH — [pandoc.org/installing.html](https://pandoc.org/installing.html)
  (ou `pip install pypandoc-binary` como fallback)
- `wkhtmltopdf` no PATH — [wkhtmltopdf.org](https://wkhtmltopdf.org/downloads.html)
  (apenas para `--pdf-engine wkhtmltopdf`)

### Temas CSS disponíveis

| Theme | Descrição |
|---|---|
| *(padrão)* | Estilo GitHub com suporte a capa de documento |
| `github` | GitHub Markdown puro |
| `academic` | Layout acadêmico |
| `minimal` | Minimalista |

```bash
python3 docs/export_doc.py doc.md --theme academic
```

---

## Estrutura do repositório

```
dev-setup/
├── setup.sh                  # Entry point interativo (menu de módulos)
├── requirements.txt          # Dependências Python
├── lib/
│   └── common.sh             # Funções compartilhadas (log, prompt, helpers)
│
├── # ── Contexto 1: Configuração de ambiente ──────────────────────────────
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
│
└── # ── Contexto 2: Documentação ───────────────────────────────────────────
    docs/
    ├── export_doc.py         # Converte .md → HTML ou PDF
    ├── pandoc_mermaid.lua    # Filtro Lua para diagramas Mermaid
    └── assets/
        ├── doc.css           # CSS padrão
        └── themes/           # Temas alternativos
```

---

## Adicionando novos utilitários

### Novo módulo de setup (contexto 1)

1. Crie a pasta e o script (ex: `docker/setup.sh`) usando `lib/common.sh`
2. Registre em `setup.sh`:

```bash
MODULES=(
    ...
    "docker|Instalar Docker|docker/setup.sh"
)
```

### Novo contexto

Crie uma pasta dedicada com seus scripts e documente aqui uma nova seção numerada.
