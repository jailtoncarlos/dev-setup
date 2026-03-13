#!/usr/bin/env python3
"""Converte um documento Markdown para HTML ou PDF usando pandoc.

Formatos de saída
-----------------
  html  — HTML auto-contido (CSS e JS embutidos). Padrão.
  pdf   — PDF gerado a partir do HTML. Requer --pdf-engine (veja abaixo).

Motores de PDF (--pdf-engine)
------------------------------
  playwright (padrão)
      Gera HTML intermediário e renderiza via Chromium headless.
      Preserva CSS, fontes e diagramas Mermaid (flowchart, sequence, etc.).
      Use quando o documento tiver diagramas ou layout visual elaborado.
      Requer: pip install playwright && playwright install chromium

  wkhtmltopdf
      Converte diretamente via pandoc + wkhtmltopdf. Mais leve e rápido,
      mas NÃO executa JavaScript — diagramas Mermaid aparecem como texto bruto.
      Indicado para documentos simples, sem diagramas.
      Requer: wkhtmltopdf instalado no sistema (https://wkhtmltopdf.org)

Diagramas Mermaid (HTML)
-------------------------
  O filtro Lua ``pandoc_mermaid.lua`` (mesmo diretório) converte blocos
  ``\`\`\`mermaid`` em ``<pre class="mermaid">…</pre>`` sem a tag ``<code>``
  intermediária que o pandoc gera por padrão — garantindo que o Mermaid.js
  leia o conteúdo corretamente, inclusive para ``flowchart LR``.
"""

from __future__ import annotations

import argparse
import logging
import re
import shutil
import subprocess
import tempfile
import urllib.request
from pathlib import Path
from typing import Iterable

SCRIPT_DIR = Path(__file__).parent

DEFAULT_FORMAT = "html"
DEFAULT_OUTPUT_DIR = Path("docs/build")
DEFAULT_CSS = SCRIPT_DIR / "assets" / "doc.css"
DEFAULT_LUA_FILTER = SCRIPT_DIR / "pandoc_mermaid.lua"
_MERMAID_JS = SCRIPT_DIR / "assets" / "mermaid.min.js"
_MERMAID_CDN = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"

logger = logging.getLogger("export_doc")


def _get_mermaid_js() -> Path | None:
    """Retorna caminho local do mermaid.min.js, baixando na primeira vez se necessário."""
    if _MERMAID_JS.exists():
        return _MERMAID_JS
    logger.info(
        "mermaid.min.js não encontrado em %s. Baixando de %s …",
        _MERMAID_JS,
        _MERMAID_CDN,
    )
    try:
        _MERMAID_JS.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(_MERMAID_CDN, _MERMAID_JS)
        logger.info("mermaid.min.js salvo em %s", _MERMAID_JS)
        return _MERMAID_JS
    except Exception as exc:
        logger.warning(
            "Não foi possível baixar mermaid.min.js: %s. Diagramas não serão renderizados.",
            exc,
        )
        return None


def _build_mermaid_init(tmp_dir: str, mermaid_js: Path) -> Path:
    """Cria snippet HTML de inicialização do mermaid para --include-after-body.

    O filtro Lua garante que os blocos mermaid cheguem como:
        <pre class="mermaid">conteúdo</pre>
    sem a tag <code> intermediária, então não é necessária nenhuma manipulação
    de DOM para desempacotar o conteúdo antes de inicializar o Mermaid.js.
    """
    snippet = Path(tmp_dir) / "mermaid-init.html"
    snippet.write_text(
        f'<script src="{mermaid_js.resolve()}"></script>\n'
        "<script>\n"
        # Reposiciona <div class="capa"> antes do sumário (#TOC).
        # Pandoc sempre coloca o TOC antes do conteúdo, então a capa ficaria depois sem isso.
        "var capa = document.querySelector('div.capa');\n"
        "var toc  = document.getElementById('TOC');\n"
        "if (capa && toc) { toc.parentNode.insertBefore(capa, toc); }\n"
        "else if (capa) { document.body.insertBefore(capa, document.body.firstChild); }\n"
        "\n"
        "mermaid.initialize({ startOnLoad: true, securityLevel: 'loose', theme: 'default' });\n"
        "</script>\n",
        encoding="utf-8",
    )
    return snippet


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Converte documento Markdown para PDF ou HTML via pandoc.\n\n"
            "Modo padrão: gera um único arquivo com todos os .md linkados incorporados "
            "como apêndices (HTML auto-contido, sem dependência de internet).\n"
            "Com --split: gera um HTML por arquivo .md linkado e reescreve os links "
            "para que funcionem entre si."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", type=Path, help="Arquivo Markdown de entrada (.md).")
    parser.add_argument(
        "--format",
        choices=["html", "pdf"],
        default=DEFAULT_FORMAT,
        dest="output_format",
        help="Formato de saída (padrão: html).",
    )
    parser.add_argument(
        "--pdf-engine",
        choices=["playwright", "wkhtmltopdf"],
        default="playwright",
        dest="pdf_engine",
        help=(
            "Motor de geração de PDF. Usado apenas com --format pdf. Padrão: playwright.\n\n"
            "  playwright   — Gera HTML intermediário e renderiza via Chromium (headless).\n"
            "                 Preserva CSS, fontes e diagramas Mermaid (flowchart, sequence, etc.).\n"
            "                 Requer: pip install playwright && playwright install chromium\n\n"
            "  wkhtmltopdf  — Converte diretamente via pandoc + wkhtmltopdf.\n"
            "                 Mais leve e rápido, mas NÃO executa JavaScript.\n"
            "                 Diagramas Mermaid aparecerão como texto bruto, não renderizados.\n"
            "                 Indicado para documentos sem diagramas.\n"
            "                 Requer: wkhtmltopdf instalado no sistema (não é pacote pip)."
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Caminho do arquivo de saída. Padrão: docs/build/<nome>.<formato>.",
    )
    parser.add_argument(
        "--title",
        default=None,
        help="Título do documento. Padrão: nome do arquivo de entrada.",
    )
    parser.add_argument(
        "--toc-depth",
        type=int,
        default=3,
        help="Profundidade do índice (TOC) (padrão: 3).",
    )
    parser.add_argument(
        "--css",
        type=Path,
        default=DEFAULT_CSS,
        help=f"Arquivo CSS. Padrão: {DEFAULT_CSS}.",
    )
    parser.add_argument(
        "--theme",
        type=str,
        default=None,
        help=(
            "Tema CSS alternativo (nome sem extensão, ex: github, academic, minimal). "
            f"Busca em {SCRIPT_DIR / 'assets' / 'themes'}."
        ),
    )
    parser.add_argument(
        "--lua-filter",
        type=Path,
        default=DEFAULT_LUA_FILTER,
        dest="lua_filter",
        help=f"Filtro Lua para blocos mermaid. Padrão: {DEFAULT_LUA_FILTER}.",
    )
    parser.add_argument(
        "--split",
        action="store_true",
        default=False,
        help=(
            "Gera um HTML individual por arquivo .md linkado e reescreve os links "
            "para que funcionem entre si."
        ),
    )
    parser.add_argument(
        "--appendix",
        type=Path,
        action="append",
        default=[],
        help="Apêndice adicional .md (pode repetir).",
    )
    parser.add_argument(
        "--no-follow",
        action="store_true",
        default=False,
        dest="no_follow",
        help="Ignora links para outros .md — gera apenas o documento principal.",
    )
    return parser


def _resolve_pandoc_path() -> str:
    binary = shutil.which("pandoc")
    if binary:
        return binary
    try:
        import pypandoc  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "pandoc não encontrado no PATH. "
            "Instale o pandoc no sistema ou 'pip install pypandoc-binary'."
        ) from exc
    try:
        return str(pypandoc.get_pandoc_path())
    except OSError as exc:
        raise RuntimeError(
            "pypandoc instalado, mas binário do pandoc não encontrado. "
            "Use pypandoc-binary ou instale pandoc no sistema."
        ) from exc


def _discover_linked_md_files(main_doc: Path) -> list[Path]:
    content = main_doc.read_text(encoding="utf-8")
    base_dir = main_doc.parent
    found: list[Path] = []
    seen: set[Path] = set()
    for href in re.findall(r"\[.*?\]\(([^)]+\.md(?:#[^)]*)?)\)", content):
        href_path = href.split("#")[0]
        if href_path.startswith(("http://", "https://")):
            continue
        candidate = (base_dir / href_path).resolve()
        if candidate.exists() and candidate not in seen:
            seen.add(candidate)
            found.append(candidate)
    return found


def _collect_linked(main_doc: Path, extra: list[Path]) -> list[Path]:
    files = _discover_linked_md_files(main_doc) + extra
    seen: set[Path] = set()
    unique: list[Path] = []
    for path in files:
        resolved = path.resolve()
        if resolved not in seen:
            seen.add(resolved)
            unique.append(path)
    return unique


def _rewrite_md_links_to_html(content: str, main_doc: Path) -> str:
    base_dir = main_doc.parent

    def replace(m: re.Match) -> str:
        text, href = m.group(1), m.group(2)
        if href.startswith(("http://", "https://", "#")):
            return m.group(0)
        href_path, _, fragment = href.partition("#")
        if not href_path.endswith(".md"):
            return m.group(0)
        candidate = (base_dir / href_path).resolve()
        if not candidate.exists():
            return m.group(0)
        new_href = candidate.stem + ".html"
        if fragment:
            new_href += f"#{fragment}"
        return f"[{text}]({new_href})"

    return re.sub(r"\[([^\]]*)\]\(([^)]+)\)", replace, content)


def _read_text(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"Arquivo não encontrado: {path}")
    return path.read_text(encoding="utf-8")


def _page_break(output_format: str) -> str:
    if output_format == "pdf":
        return r"\newpage"
    return '<div style="page-break-after: always;"></div>'


def _compose_markdown(
    main_doc: Path, appendices: Iterable[Path], output_format: str
) -> str:
    content = [_read_text(main_doc).strip(), ""]
    appendices = list(appendices)
    if not appendices:
        return "\n\n".join(content)
    content += [_page_break(output_format), "", "## Apêndices", ""]
    for appendix in appendices:
        content += [_page_break(output_format), "", _read_text(appendix).strip(), ""]
    return "\n".join(content).strip() + "\n"


def _build_resource_path(paths: Iterable[Path]) -> str:
    seen: set[str] = set()
    unique: list[str] = []
    for path in paths:
        candidate = str(path.resolve())
        if candidate not in seen:
            seen.add(candidate)
            unique.append(candidate)
    return ":".join(unique)


def _md_to_pdf_wkhtmltopdf(
    pandoc_path: str,
    source: Path,
    output: Path,
    title: str,
    toc_depth: int,
    resource_path: str,
    css: Path | None = None,
    lua_filter: Path | None = None,
) -> None:
    """Converte Markdown diretamente para PDF via pandoc + wkhtmltopdf.

    Mais leve que o Playwright, mas não executa JavaScript — diagramas Mermaid
    não serão renderizados. Indicado para documentos sem diagramas.
    """
    if not shutil.which("wkhtmltopdf"):
        raise RuntimeError(
            "wkhtmltopdf não encontrado no PATH. "
            "Instale em: https://wkhtmltopdf.org/downloads.html"
        )
    cmd = [
        pandoc_path,
        str(source),
        "--from", "gfm",
        "--to", "html5",
        "--output", str(output),
        "--standalone",
        "--pdf-engine", "wkhtmltopdf",
        "--toc",
        "--toc-depth", str(toc_depth),
        "--metadata", f"title={title}",
        "--resource-path", resource_path,
    ]
    if lua_filter and lua_filter.exists():
        cmd += ["--lua-filter", str(lua_filter)]
    if css and css.exists():
        cmd += ["--css", str(css)]
    subprocess.run(cmd, check=True)


def _html_to_pdf_playwright(html_path: Path, output_pdf: Path) -> None:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise RuntimeError(
            "playwright não encontrado. Execute: pip install playwright && playwright install chromium"
        ) from exc

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto(f"file://{html_path.resolve()}", wait_until="domcontentloaded")
        try:
            page.wait_for_function(
                "() => {"
                "  const blocks = document.querySelectorAll('pre.mermaid');"
                "  return blocks.length === 0 || [...blocks].every(b => b.querySelector('svg'));"
                "}",
                timeout=10000,
            )
        except Exception:
            pass
        page.pdf(
            path=str(output_pdf),
            format="A4",
            print_background=True,
            margin={"top": "1.5cm", "bottom": "1.5cm", "left": "1.5cm", "right": "1.5cm"},
        )
        browser.close()


def _resolve_css(css_arg: Path, theme: str | None) -> Path | None:
    if theme:
        theme_path = SCRIPT_DIR / "assets" / "themes" / f"{theme}.css"
        if theme_path.exists():
            return theme_path
        logger.warning("Tema '%s' não encontrado em %s. Usando CSS padrão.", theme, theme_path.parent)
    if css_arg and css_arg.exists():
        return css_arg
    return None


def _run_pandoc_html(
    pandoc_path: str,
    source: Path,
    output: Path,
    title: str,
    toc_depth: int,
    resource_path: str,
    css: Path | None = None,
    mermaid_init: Path | None = None,
    lua_filter: Path | None = None,
) -> None:
    cmd = [
        pandoc_path,
        str(source),
        "--from", "gfm",
        "--to", "html5",
        "--output", str(output),
        "--standalone",
        "--self-contained",
        "--toc",
        "--toc-depth", str(toc_depth),
        "--metadata", f"title={title}",
        "--resource-path", resource_path,
    ]
    if lua_filter and lua_filter.exists():
        cmd += ["--lua-filter", str(lua_filter)]
    if css and css.exists():
        cmd += ["--css", str(css)]
    if mermaid_init and mermaid_init.exists():
        cmd += ["--include-after-body", str(mermaid_init)]
    subprocess.run(cmd, check=True)


def _resolve_output(input_path: Path, output_format: str, output_arg: Path | None) -> Path:
    if output_arg:
        return output_arg
    return DEFAULT_OUTPUT_DIR / f"{input_path.stem}.{output_format}"


def _generate_individual_htmls(
    linked: list[Path],
    output_dir: Path,
    pandoc_path: str,
    toc_depth: int,
    css: Path | None,
    mermaid_init: Path | None = None,
    lua_filter: Path | None = None,
) -> None:
    for md_path in linked:
        out = output_dir / f"{md_path.stem}.html"
        title = md_path.stem.replace("_", " ").replace("-", " ")
        resource_path = _build_resource_path([md_path.parent, Path(".")])
        _run_pandoc_html(
            pandoc_path=pandoc_path,
            source=md_path,
            output=out,
            title=title,
            toc_depth=toc_depth,
            resource_path=resource_path,
            css=css,
            mermaid_init=mermaid_init,
            lua_filter=lua_filter,
        )
        logger.info("  → %s", out)


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )
    args = _build_parser().parse_args()

    input_path: Path = args.input
    output_format: str = args.output_format
    output_path: Path = _resolve_output(input_path, output_format, args.output)
    title: str = args.title or input_path.stem.replace("_", " ").replace("-", " ")
    output_path.parent.mkdir(parents=True, exist_ok=True)

    pandoc_path = _resolve_pandoc_path()
    css = _resolve_css(args.css, args.theme)
    lua_filter: Path | None = args.lua_filter if args.lua_filter.exists() else None

    if lua_filter:
        logger.info("Filtro Lua: %s", lua_filter)
    else:
        logger.warning("pandoc_mermaid.lua não encontrado — diagramas Mermaid podem não renderizar.")

    linked = [] if args.no_follow else _collect_linked(input_path, args.appendix)

    if linked:
        logger.info("Arquivos .md linkados encontrados (%d):", len(linked))
        for lk in linked:
            logger.info("  - %s", lk)

    mermaid_js = _get_mermaid_js()

    if output_format == "pdf" or not args.split:
        merged = _compose_markdown(input_path, linked, output_format)
        resource_dirs = [input_path.parent, Path("."), Path("docs")]
        resource_dirs.extend(lk.parent for lk in linked)
        resource_path = _build_resource_path(resource_dirs)

        with tempfile.TemporaryDirectory(prefix="export_doc_") as tmp:
            merged_path = Path(tmp) / "merged.md"
            merged_path.write_text(merged, encoding="utf-8")
            mermaid_init = _build_mermaid_init(tmp, mermaid_js) if mermaid_js else None

            if output_format == "pdf":
                if args.pdf_engine == "wkhtmltopdf":
                    logger.info("Gerando PDF via wkhtmltopdf (sem renderização de Mermaid)…")
                    _md_to_pdf_wkhtmltopdf(
                        pandoc_path=pandoc_path,
                        source=merged_path,
                        output=output_path,
                        title=title,
                        toc_depth=args.toc_depth,
                        resource_path=resource_path,
                        css=css,
                        lua_filter=lua_filter,
                    )
                else:
                    html_path = Path(tmp) / f"{input_path.stem}.html"
                    _run_pandoc_html(
                        pandoc_path=pandoc_path,
                        source=merged_path,
                        output=html_path,
                        title=title,
                        toc_depth=args.toc_depth,
                        resource_path=resource_path,
                        css=css,
                        mermaid_init=mermaid_init,
                        lua_filter=lua_filter,
                    )
                    logger.info("Convertendo HTML → PDF via Playwright…")
                    _html_to_pdf_playwright(html_path, output_path)
            else:
                _run_pandoc_html(
                    pandoc_path=pandoc_path,
                    source=merged_path,
                    output=output_path,
                    title=title,
                    toc_depth=args.toc_depth,
                    resource_path=resource_path,
                    css=css,
                    mermaid_init=mermaid_init,
                    lua_filter=lua_filter,
                )
    else:
        with tempfile.TemporaryDirectory(prefix="export_doc_") as tmp:
            mermaid_init = _build_mermaid_init(tmp, mermaid_js) if mermaid_js else None

            if linked:
                logger.info("Gerando HTMLs individuais para os links...")
                _generate_individual_htmls(
                    linked=linked,
                    output_dir=output_path.parent,
                    pandoc_path=pandoc_path,
                    toc_depth=args.toc_depth,
                    css=css,
                    mermaid_init=mermaid_init,
                    lua_filter=lua_filter,
                )

            rewritten = _rewrite_md_links_to_html(
                input_path.read_text(encoding="utf-8"), input_path
            )
            resource_path = _build_resource_path([input_path.parent, Path(".")])
            rewritten_path = Path(tmp) / input_path.name
            rewritten_path.write_text(rewritten, encoding="utf-8")
            _run_pandoc_html(
                pandoc_path=pandoc_path,
                source=rewritten_path,
                output=output_path,
                title=title,
                toc_depth=args.toc_depth,
                resource_path=resource_path,
                css=css,
                mermaid_init=mermaid_init,
                lua_filter=lua_filter,
            )

    logger.info("Documento principal gerado: %s", output_path.resolve())


if __name__ == "__main__":
    main()
