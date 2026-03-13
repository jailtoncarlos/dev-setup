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

Scripts interativos para configurar uma nova máquina Linux/WSL2 para trabalhar com múltiplos repositórios em plataformas diferentes.

### O problema: múltiplos repositórios, múltiplas identidades

É comum um desenvolvedor trabalhar com projetos em plataformas distintas — por exemplo:

| Projeto | Plataforma | Email do commit |
|---|---|---|
| `universidade/sistema-academico` | gitlab.universidade.edu.br | `dev@universidade.edu.br` |
| `minha-empresa/sistema-web` | github.com | `dev@gmail.com` |
| `cliente/api-interna` | gitlab.cliente.com.br | `dev@cliente.com.br` |

Sem configuração adequada, dois problemas acontecem:

1. **Commits com autoria errada** — o Git usa um único e-mail global, então commits aparecem como de um usuário desconhecido na plataforma errada.
2. **Autenticação SSH ambígua** — sem chaves separadas por plataforma, o SSH pode usar a chave errada ou falhar ao autenticar.

### Conceito central: Organização

O conceito de **org** é o elemento central que conecta todos os módulos. O nome da org é derivado automaticamente do domínio da URL do repositório:

| URL | Host detectado | Org sugerida |
|---|---|---|
| `git@gitlab.universidade.edu.br:ti/sistema-academico.git` | `gitlab.universidade.edu.br` | `universidade` |
| `git@github.com:minha-empresa/sistema-web.git` | `github.com` | `github` |
| `git@gitlab.cliente.com.br:dev/api-interna.git` | `gitlab.cliente.com.br` | `cliente` |

A partir do nome da org, tudo é derivado automaticamente:

```
org: universidade
 ├── SSH key:     ~/.ssh/universidade_id_ed25519
 ├── SSH config:  Host gitlab.universidade.edu.br → IdentityFile universidade_id_ed25519
 ├── Git config:  includeIf "gitdir:~/workspace/universidade/" → email universidade
 ├── Workspace:   ~/workspace/universidade/<projeto>
 └── Clone:       git clone <url> ~/workspace/universidade/<projeto>
```

#### Como o Git sabe qual e-mail usar?

O mecanismo `includeIf` do Git aplica uma configuração diferente dependendo do diretório onde o repositório está clonado:

```
~/.gitconfig
├── [user] email = dev@gmail.com                     ← padrão (fora de qualquer org)
├── [includeIf "gitdir:~/workspace/universidade/"]
│     path = ~/.gitconfig-universidade               ← email: dev@universidade.edu.br
└── [includeIf "gitdir:~/workspace/cliente/"]
      path = ~/.gitconfig-cliente                    ← email: dev@cliente.com.br
```

Um `git commit` dentro de `~/workspace/universidade/sistema-academico/` usará automaticamente o e-mail da universidade, sem nenhuma configuração manual por repositório.

#### Como o SSH sabe qual chave usar?

O `~/.ssh/config` mapeia cada host a uma chave dedicada:

```
~/.ssh/config
├── Host gitlab.universidade.edu.br  → ~/.ssh/universidade_id_ed25519
├── Host github.com                  → ~/.ssh/github_id_ed25519
└── Host gitlab.cliente.com.br       → ~/.ssh/cliente_id_ed25519
```

O script de `ssh-agent` (instalado em `~/.add_ssh_keys.sh` e carregado pelo `.bashrc`) inicia o agente automaticamente e carrega todas as chaves ao abrir o terminal.

### Como usar

```bash
git clone https://github.com/jailtoncarlos/dev-setup.git ~/dev-setup
cd ~/dev-setup
bash devsetup.sh
```

O menu principal oferece três opções:

```
╔══════════════════════════════════════════════════════╗
║               dev-setup — Menu Principal             ║
╚══════════════════════════════════════════════════════╝

  1) Preparar ambiente
     Configura SSH, Git, workspace e shell para múltiplos repositórios

  2) Clonar projeto
     Detecta a org pelo domínio da URL e clona no diretório correto

  3) Gerar HTML/PDF de arquivo .md
     Converte Markdown com suporte a diagramas Mermaid

  q) Sair
```

Ao iniciar, o script exibe o estado atual do ambiente:

```
╔══════════════════════════════════════════════════════╗
║            Estado do ambiente atual                  ║
╚══════════════════════════════════════════════════════╝

  Git
  [✓] Nome global         Jailton Paiva
  [✓] Email global        usuario@gmail.com
  [✓] Perfis de org       universidade, cliente

  SSH
  [✓] Chaves              universidade, cliente
  [✓] ~/.ssh/config       2 host(s) configurado(s)

  Shell  (~/.bashrc)
  [✓] ssh-agent automático

  Workspace
  [✓] Diretório base      ~/workspace  (universidade, cliente, pessoal)
```

### Fluxo completo: máquina nova → projetos rodando

**Passo 1 — Clonar o dev-setup** (única vez que você usa HTTPS)

```bash
git clone https://github.com/jailtoncarlos/dev-setup.git ~/dev-setup
cd ~/dev-setup
bash devsetup.sh
```

**Passo 2 — Opção `1) Preparar ambiente`**

O script pergunta:
- Seu nome e e-mail padrão
- Diretório base dos projetos (`~/workspace/` sugerido)
- Para cada organização: nome, host Git e e-mail

E configura automaticamente para cada org:
- Gera `~/.ssh/<org>_id_ed25519`
- Adiciona o host em `~/.ssh/config`
- Cria `~/.gitconfig-<org>` e o `includeIf` em `~/.gitconfig`
- Cria `~/workspace/<org>/`
- Exibe a chave pública para cadastro na plataforma

**Passo 3 — Adicionar as chaves públicas nas plataformas**

O script exibe cada chave e aguarda você cadastrá-la:

| Plataforma | URL de configuração |
|---|---|
| GitHub | `https://github.com/settings/keys` |
| GitLab (auto-hospedado) | `https://<seu-gitlab>/-/profile/keys` |
| Bitbucket | `https://bitbucket.org/account/settings/ssh-keys/` |

**Passo 4 — Abrir novo terminal** (para recarregar o `.bashrc`)

```bash
ssh-add -l                                    # chaves carregadas?
ssh -T git@github.com                         # autenticação ok?
ssh -T git@gitlab.universidade.edu.br         # substitua pelo seu host
```

**Passo 5 — Opção `2) Clonar projeto`**

Informe a URL do repositório. O script detecta o host, sugere a org, confirma o destino e clona:

```bash
URL: git@gitlab.universidade.edu.br:ti/sistema-academico.git

[INFO]  Host detectado:  gitlab.universidade.edu.br
[INFO]  Org sugerida:    universidade
[CMD]   git clone git@gitlab.universidade.edu.br:ti/sistema-academico.git ~/workspace/universidade/sistema-academico
[OK]    Clone concluído: ~/workspace/universidade/sistema-academico

Identidade de commits neste repositório:
  Nome:  Seu Nome
  Email: dev@universidade.edu.br
```

### Requisitos

- Linux ou WSL2
- `bash` >= 4
- `git`, `ssh-keygen`, `curl`

---

## 2. Documentação — Markdown para HTML/PDF

Converte arquivos Markdown para HTML ou PDF via pandoc, com suporte a diagramas Mermaid (`flowchart LR`, `sequenceDiagram`, C4, etc.).

Disponível via menu (`opção 3`) ou diretamente:

```bash
python3 docs/export_doc.py docs/DEPLOY.md
```

### Uso direto

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

---

## Estrutura do repositório

```
dev-setup/
├── devsetup.sh               # Entry point — menu principal + painel de estado
├── requirements.txt          # Dependências Python (docs)
│
├── lib/
│   ├── common.sh             # Funções de log, prompt e cores
│   └── orgs.sh               # Detecção de org por URL, listagem de orgs configuradas
│
├── # ── Contexto 1: Configuração de ambiente ──────────────────────────────
├── setup/
│   └── main.sh               # Configuração org-cêntrica (SSH + Git + workspace + shell)
├── clone/
│   └── clone.sh              # Clone com detecção automática de org pela URL
├── shell/
│   └── setup.sh              # Configuração do .bashrc/.zshrc
├── ssh/
│   └── templates/
│       └── add_ssh_keys.sh   # Script de ssh-agent (instalado em ~/.add_ssh_keys.sh)
├── tools/
│   └── nvm.sh                # Instalação do NVM
│
└── # ── Contexto 2: Documentação ────────────────────────────────────────────
    docs/
    ├── export_doc.py         # Converte .md → HTML ou PDF
    ├── pandoc_mermaid.lua    # Filtro Lua para diagramas Mermaid
    └── assets/
        ├── doc.css           # CSS padrão
        └── themes/           # Temas alternativos (github, academic, minimal)
```

---

## Adicionando novos utilitários

### Novo módulo dentro de um contexto existente

1. Crie o script na pasta do contexto (ex: `setup/docker.sh`)
2. Use `lib/common.sh` para logs e prompts padronizados
3. Chame-o a partir do menu em `devsetup.sh` ou do orquestrador do contexto

### Novo contexto

1. Crie uma pasta dedicada com seus scripts
2. Adicione uma opção numerada no menu de `devsetup.sh`
3. Documente aqui uma nova seção numerada
