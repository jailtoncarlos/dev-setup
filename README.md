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

Scripts interativos para configurar uma nova máquina Linux/WSL2 do zero para trabalhar com múltiplos repositórios em plataformas diferentes.

### O problema: múltiplos repositórios, múltiplas identidades

É comum um desenvolvedor trabalhar simultaneamente com projetos em plataformas distintas — por exemplo:

| Projeto | Plataforma | Email do commit |
|---|---|---|
| `cosinf/suap` | gitlab.ifrn.edu.br | `usuario@ifrn.edu.br` |
| `Prisma-Consultoria/siscan-rpa` | github.com | `usuario@gmail.com` |
| `smart/integra` | git.lais.huol.ufrn.br | `usuario@lais.huol.ufrn.br` |

Sem configuração adequada, dois problemas acontecem:

1. **Commits sem autoria correta** — o Git usa um único e-mail global, então commits no GitLab do IFRN aparecem como de um usuário desconhecido (e-mail não cadastrado na plataforma).
2. **Autenticação SSH ambígua** — sem chaves separadas por plataforma, o SSH pode usar a chave errada ou falhar ao autenticar.

### O que é configurado

| Módulo | O que faz | Arquivo alterado |
|---|---|---|
| **ssh** | Gera uma chave `ed25519` por plataforma e mapeia cada host à sua chave | `~/.ssh/config`, `~/.ssh/id_ed25519_<plataforma>` |
| **git** | Define e-mail global (padrão) e e-mails específicos por diretório de trabalho | `~/.gitconfig`, `~/.gitconfig-<org>` |
| **workspace** | Cria a estrutura de pastas por organização (`~/workspace/ifrn/`, `~/workspace/lais/`, etc.) | — |
| **shell** | Inicia o `ssh-agent` automaticamente no login e carrega todas as chaves | `~/.bashrc` / `~/.zshrc` |
| **tools/nvm** | Instala o [NVM](https://github.com/nvm-sh/nvm) para gerenciar versões do Node.js | `~/.nvm/` |

#### Como o Git sabe qual e-mail usar?

O módulo **git** usa o mecanismo `includeIf` do Git, que aplica uma configuração diferente dependendo do diretório onde o repositório está clonado:

```
~/.gitconfig
├── [user] email = usuario@gmail.com   ← padrão (GitHub)
├── [includeIf "gitdir:~/workspace/ifrn/"]
│     path = ~/.gitconfig-ifrn         ← email: usuario@ifrn.edu.br
└── [includeIf "gitdir:~/workspace/lais/"]
      path = ~/.gitconfig-lais         ← email: usuario@lais.huol.ufrn.br
```

Assim, um `git commit` dentro de `~/workspace/ifrn/suap/` usa automaticamente o e-mail do IFRN, sem nenhuma configuração manual por repositório.

#### Como o SSH sabe qual chave usar?

O módulo **ssh** configura o `~/.ssh/config` mapeando cada host a uma chave dedicada:

```
~/.ssh/config
├── Host github.com          → ~/.ssh/id_ed25519_github
├── Host gitlab.ifrn.edu.br  → ~/.ssh/id_ed25519_gitlab_ifrn
└── Host git.lais.huol.ufrn.br → ~/.ssh/id_ed25519_gitlab_lais
```

O módulo **shell** garante que o `ssh-agent` já esteja rodando e com todas as chaves carregadas ao abrir o terminal, evitando digitação de senha repetida.

### Fluxo completo: máquina nova → projetos rodando

> Exemplo com os projetos `cosinf/suap` (IFRN), `Prisma-Consultoria/siscan-rpa` (GitHub) e `smart/integra` (LAIS).

**Passo 1 — Clonar o dev-setup** (única vez que você usa HTTPS)

```bash
git clone https://github.com/jailtoncarlos/dev-setup.git ~/dev-setup
cd ~/dev-setup
```

**Passo 2 — Executar o setup**

```bash
bash setup.sh
```

O menu interativo guia cada etapa. Ao final, terão sido configurados:
- Chaves SSH geradas para cada plataforma
- `~/.ssh/config` com os três hosts
- `~/.gitconfig` com e-mails por diretório
- `~/workspace/ifrn/`, `~/workspace/lais/`, `~/workspace/prisma_roche/` criados
- `~/.bashrc` com carregamento automático do `ssh-agent`

**Passo 3 — Adicionar as chaves públicas nas plataformas**

O script exibe cada chave pública e a URL de onde cadastrá-la. Acesse cada URL e cole a chave:

| Plataforma | URL de configuração |
|---|---|
| GitHub | `https://github.com/settings/keys` |
| GitLab IFRN | `https://gitlab.ifrn.edu.br/-/profile/keys` |
| GitLab LAIS | `https://git.lais.huol.ufrn.br/-/profile/keys` |

**Passo 4 — Abrir novo terminal** (para o `.bashrc` ser recarregado)

```bash
# Verifique que as chaves estão carregadas
ssh-add -l

# Teste a autenticação em cada plataforma
ssh -T git@github.com
ssh -T git@gitlab.ifrn.edu.br
ssh -T git@git.lais.huol.ufrn.br
```

**Passo 5 — Clonar os projetos nas pastas corretas**

```bash
# IFRN → ~/workspace/ifrn/  (commits usarão usuario@ifrn.edu.br)
git clone git@gitlab.ifrn.edu.br:cosinf/suap.git ~/workspace/ifrn/suap

# GitHub → ~/workspace/prisma_roche/  (commits usarão usuario@gmail.com)
git clone git@github.com:Prisma-Consultoria/siscan-rpa.git ~/workspace/prisma_roche/siscan-rpa

# LAIS → ~/workspace/lais/  (commits usarão usuario@lais.huol.ufrn.br)
git clone git@git.lais.huol.ufrn.br:smart/integra.git ~/workspace/lais/integra
```

**Passo 6 — Verificar a identidade em cada repositório**

```bash
git -C ~/workspace/ifrn/suap config user.email
# → usuario@ifrn.edu.br

git -C ~/workspace/prisma_roche/siscan-rpa config user.email
# → usuario@gmail.com

git -C ~/workspace/lais/integra config user.email
# → usuario@lais.huol.ufrn.br
```

Pronto. A partir daqui, `git commit` em qualquer repositório usará automaticamente a identidade correta.

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
