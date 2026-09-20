#!/usr/bin/env python3
"""Monta documentos/relatorio_professor.md (modelo + saídas do R) e a página editável.

Rodar da raiz do repositório: python3 scripts/relatorio/build_report.py [saida.html]

A página é renderizada a partir de uma lista de blocos embutida como JSON.
O mesmo renderizador existe em Python (versão inicial) e em JavaScript (ao
salvar uma edição), de modo que o documento é sempre regenerado a partir do
estado, nunca serializado do DOM.
"""
import re, html, json, pathlib, sys

RAIZ = pathlib.Path(__file__).resolve().parents[2]
SAIDA_HTML = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else RAIZ / "resultados" / "relatorio_professor.html"
TITULO = "Da Verba à Patente"
FONTES = ('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
          'family=Fraunces:opsz,wght@9..144,600&family=Source+Sans+3:ital,wght@0,400;0,600;1,400'
          '&family=JetBrains+Mono:wght@400;600&display=swap">')

# ---------------------------------------------------------------- markdown
modelo = (RAIZ / "scripts/relatorio/template.md").read_text(encoding="utf8")

def trecho(nome):
    """Devolve o código R de um trecho e a saída que ele produziu."""
    arquivo = next((RAIZ / "scripts/relatorio").glob(f"{nome}_*.R"))
    codigo = arquivo.read_text(encoding="utf8").rstrip("\n")
    saida = RAIZ / "resultados/prints" / (arquivo.stem + ".out.txt")
    texto = saida.read_text(encoding="utf8").rstrip("\n") if saida.exists() else ""
    bloco = "```r\n" + codigo + "\n```\n"
    if texto.strip():
        bloco += "\n```text\n" + texto + "\n```\n"
    return bloco

md = re.sub(r"\{\{SETUP\}\}", lambda m: trecho("00"), modelo)
md = re.sub(r"\{\{(E\d\d)\}\}", lambda m: trecho(m.group(1)), md)
assert "{{" not in md, "placeholder não substituído"
# No Markdown gravado em documentos/, as figuras ficam em ../resultados/figuras/;
# a página publicada mantém o caminho figuras/ dos arquivos que ela carrega.
SAIDA_MD = RAIZ / "documentos" / "relatorio_professor.md"
SAIDA_MD.write_text(md.replace("](figuras/", "](../resultados/figuras/"), encoding="utf8")

# ------------------------------------------------------------------ blocos
BLOCOS = []

def bloco(tag, cls, conteudo, editavel=True, ident=None):
    BLOCOS.append({"id": ident or f"b{len(BLOCOS)}", "tag": tag, "cls": cls,
                   "html": conteudo, "edit": editavel})

def inline(t):
    t = html.escape(t, quote=False).replace("\\$", "$")
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![\w*])\*(?!\s)([^*]+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', t)
    return t

linhas = md.split("\n")
i = 0
titulos = []
paragrafo = []
primeiro = True

def fecha_paragrafo():
    global paragrafo, primeiro
    if not paragrafo:
        return
    bloco("p", "meta" if primeiro else "", inline(" ".join(paragrafo)))
    primeiro = False
    paragrafo = []

while i < len(linhas):
    ln = linhas[i]
    if ln.startswith("```"):
        fecha_paragrafo()
        lang = ln[3:].strip()
        corpo = []
        i += 1
        while i < len(linhas) and not linhas[i].startswith("```"):
            corpo.append(linhas[i])
            i += 1
        i += 1
        txt = html.escape("\n".join(corpo), quote=False)
        if lang == "text":
            bloco("figure", "print console",
                  f'<div class="print-label">saída</div><pre class="console">{txt}</pre>',
                  editavel=False)
        else:
            bloco("figure", "print",
                  f'<div class="print-label">R</div><pre class="code">{txt}</pre>',
                  editavel=False)
        continue
    if ln.startswith("# "):
        fecha_paragrafo()
        bloco("h1", "", inline(ln[2:]))
        i += 1
        continue
    if ln.startswith("## "):
        fecha_paragrafo()
        ident = f"s{len(titulos) + 1}"
        titulos.append((ident, ln[3:]))
        bloco("h2", "", inline(ln[3:]), ident=ident)
        i += 1
        continue
    if ln.startswith("### "):
        fecha_paragrafo()
        bloco("h3", "", inline(ln[4:]))
        i += 1
        continue
    m = re.match(r"^!\[(.*?)\]\((.*?)\)\s*$", ln)
    if m:
        fecha_paragrafo()
        bloco("figure", "fig",
              f'<img src="{m.group(2)}" alt="{html.escape(m.group(1))}" loading="lazy">'
              f'<figcaption>{inline(m.group(1))}</figcaption>')
        i += 1
        continue
    if ln.startswith("|"):
        fecha_paragrafo()
        linhas_tab = []
        while i < len(linhas) and linhas[i].startswith("|"):
            linhas_tab.append(linhas[i])
            i += 1
        celulas = lambda r: [c.strip() for c in r.strip().strip("|").split("|")]
        cabeca = celulas(linhas_tab[0])
        corpo = [celulas(r) for r in linhas_tab[2:]]
        t = "<table><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in cabeca) + "</tr></thead><tbody>"
        for r in corpo:
            t += "<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>"
        bloco("div", "tbl", t + "</tbody></table>")
        continue
    if ln.startswith("> "):
        fecha_paragrafo()
        cit = []
        while i < len(linhas) and linhas[i].startswith("> "):
            cit.append(linhas[i][2:])
            i += 1
        texto = " ".join(cit)
        rotulo = re.match(r"^\*\*([^.*]+)\.\*\*", texto)
        tipo = {"Diagnóstico": "diag", "Melhoria incorporada": "change",
                "Leitura revisada": "good", "Mudança": "change",
                "Depois": "good"}.get(rotulo.group(1) if rotulo else "", "note")
        bloco("div", f"callout {tipo}", f"<p>{inline(texto)}</p>")
        continue
    if re.match(r"^- ", ln):
        fecha_paragrafo()
        itens = []
        while i < len(linhas) and re.match(r"^- ", linhas[i]):
            itens.append(linhas[i][2:])
            i += 1
        bloco("ul", "", "".join(f"<li>{inline(x)}</li>" for x in itens))
        continue
    if re.match(r"^\d+\. ", ln):
        fecha_paragrafo()
        itens = []
        while i < len(linhas) and re.match(r"^\d+\. ", linhas[i]):
            itens.append(re.sub(r"^\d+\. ", "", linhas[i]))
            i += 1
        bloco("ol", "", "".join(f"<li>{inline(x)}</li>" for x in itens))
        continue
    if ln.strip() in ("", "---"):
        fecha_paragrafo()
        i += 1
        continue
    paragrafo.append(ln)
    i += 1
fecha_paragrafo()

# sumário, inserido antes da primeira seção e regenerado a cada edição
sumario = ('<div class="label">Sumário</div><ol>'
           + "".join(f'<li><a href="#{d}">{inline(t)}</a></li>' for d, t in titulos)
           + "</ol>")
pos = next(j for j, b in enumerate(BLOCOS) if b["id"] == "s1")
BLOCOS.insert(pos, {"id": "sumario", "tag": "nav", "cls": "toc", "html": sumario, "edit": False})

def render_bloco(b):
    cls = f' class="{b["cls"]}"' if b["cls"] else ""
    ed = " data-editavel" if b["edit"] else ""
    return f'<{b["tag"]} id="{b["id"]}"{cls}{ed}>{b["html"]}</{b["tag"]}>'

corpo_html = "\n".join(render_bloco(b) for b in BLOCOS)

# -------------------------------------------------------------------- CSS
CSS = """
:root{color-scheme:light dark;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
body{margin:0}
img{max-width:100%}
[hidden]{display:none!important}
:root{--bg:#F6F7F4;--ink:#1C211F;--muted:#5B6661;--line:#D6DBD5;--accent:#0E6B5A;--rust:#B2431F;--slate:#35506B;--code-bg:#ECEFEA;--con-bg:#1F2422;--con-ink:#DCE3DD;--con-muted:#9AA59F;--con-line:#2E3532;--diag-bg:#F8ECE6;--change-bg:#E8EEF5;--good-bg:#E6F2EE;--note-bg:#EEF0EC;--img-bg:#FFFFFF;--barra-bg:#EFF1EDF2;--edit:#B2431F}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#141816;--ink:#E6EAE5;--muted:#9AA59F;--line:#2A312D;--accent:#4FBFA6;--rust:#E48660;--slate:#7FA3C7;--code-bg:#1D2320;--con-bg:#0C0F0E;--con-ink:#D5DCD7;--con-muted:#7E8A84;--con-line:#202623;--diag-bg:#2A1E19;--change-bg:#1B2430;--good-bg:#172622;--note-bg:#1E2320;--img-bg:#F2F4F1;--barra-bg:#1A1F1CF2;--edit:#E48660}}
:root[data-theme="dark"]{--bg:#141816;--ink:#E6EAE5;--muted:#9AA59F;--line:#2A312D;--accent:#4FBFA6;--rust:#E48660;--slate:#7FA3C7;--code-bg:#1D2320;--con-bg:#0C0F0E;--con-ink:#D5DCD7;--con-muted:#7E8A84;--con-line:#202623;--diag-bg:#2A1E19;--change-bg:#1B2430;--good-bg:#172622;--note-bg:#1E2320;--img-bg:#F2F4F1;--barra-bg:#1A1F1CF2;--edit:#E48660}
body{background:var(--bg);color:var(--ink);font-family:"Source Sans 3",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;font-size:17px;line-height:1.55}
main{max-width:76ch;margin:0 auto;padding-inline:clamp(16px,4vw,40px);padding-block:28px 96px}
h1,h2,h3{font-family:"Fraunces",Georgia,"Times New Roman",serif;font-weight:600;line-height:1.15;text-wrap:balance;color:var(--ink)}
h1{font-size:clamp(30px,5vw,44px);font-variation-settings:"opsz" 144;margin:0 0 12px}
h2{font-size:clamp(22px,3.2vw,28px);margin:56px 0 14px;padding-top:22px;border-top:1px solid var(--line);scroll-margin-top:72px}
h3{font-size:20px;margin:28px 0 8px}
p{margin:0 0 16px}
p.meta{color:var(--muted);font-size:15px;margin-bottom:22px}
.label{text-transform:uppercase;letter-spacing:.08em;font-size:12px;font-weight:600;color:var(--muted)}
nav.toc{background:var(--note-bg);border-radius:6px;padding:16px 20px;margin:26px 0 8px}
nav.toc ol{margin:8px 0 0;padding-left:20px;columns:2;column-gap:28px}
@media (max-width:640px){nav.toc ol{columns:1}}
nav.toc li{break-inside:avoid;margin-bottom:4px}
nav.toc a{color:inherit;text-decoration:none}
nav.toc a:hover,nav.toc a:focus-visible{text-decoration:underline}
figure{margin:20px 0}
figure.print{border:1px solid var(--line);border-radius:6px;overflow:hidden;background:var(--code-bg)}
figure.print .print-label{font:600 11px/1 "JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);padding:9px 14px;border-bottom:1px solid var(--line)}
figure.print.console{background:var(--con-bg);border-color:var(--con-line)}
figure.print.console .print-label{color:var(--con-muted);border-bottom-color:var(--con-line)}
pre{margin:0;padding:12px 14px;overflow-x:auto;font:13px/1.55 "JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre;color:var(--ink)}
pre.console{color:var(--con-ink)}
code{font:.92em "JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--code-bg);padding:1px 5px;border-radius:4px}
.callout{border-left:4px solid var(--slate);background:var(--change-bg);padding:14px 18px;margin:18px 0;border-radius:0 6px 6px 0}
.callout.diag{border-color:var(--rust);background:var(--diag-bg)}
.callout.good{border-color:var(--accent);background:var(--good-bg)}
.callout.note{border-color:var(--muted);background:var(--note-bg)}
.callout p{margin:0}
.callout p>strong:first-child{text-transform:uppercase;letter-spacing:.06em;font-size:13px;margin-right:6px}
figure.fig img{width:100%;height:auto;border:1px solid var(--line);border-radius:4px;background:var(--img-bg)}
figure.fig figcaption{color:var(--muted);font-size:14px;margin-top:8px}
.tbl{overflow-x:auto;margin:18px 0}
table{border-collapse:collapse;width:100%;font-size:15px;font-variant-numeric:tabular-nums}
th,td{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line);vertical-align:top}
th{font-weight:600;color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.05em}
ul,ol{padding-left:22px;margin:0 0 16px}
li{margin-bottom:6px}
a{color:var(--accent)}
a:focus-visible,button:focus-visible,[contenteditable]:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.barra{position:sticky;top:env(safe-area-inset-top,0px);z-index:20;display:flex;flex-wrap:wrap;gap:8px;align-items:center;background:var(--barra-bg);backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:10px clamp(16px,4vw,40px)}
.barra .marca{font-family:"Fraunces",Georgia,serif;font-weight:600;font-size:15px;margin-right:auto}
.barra button{font:600 13px/1 "Source Sans 3",system-ui,sans-serif;padding:8px 14px;border-radius:6px;border:1px solid var(--line);background:transparent;color:var(--ink);cursor:pointer}
.barra button:hover:not(:disabled){border-color:var(--accent);color:var(--accent)}
.barra button.primario{background:var(--accent);border-color:var(--accent);color:#fff}
.barra button:disabled{opacity:.5;cursor:default}
.barra .aviso{font-size:13px;color:var(--muted);flex-basis:100%}
body.modo-edicao [data-editavel]{outline:1px dashed var(--edit);outline-offset:6px;border-radius:2px}
body.modo-edicao [contenteditable="true"]:focus{outline:2px solid var(--edit);outline-offset:6px}
body.modo-edicao figure.fig figcaption{outline:1px dashed var(--edit);outline-offset:4px}
@media print{.barra{display:none}}
"""

# --------------------------------------------------------------------- JS
BOTOES = ('<button id="btn-editar" type="button" hidden>Editar textos</button>'
         '<button id="btn-salvar" type="button" class="primario" hidden>Salvar edição</button>'
         '<button id="btn-cancelar" type="button" hidden>Cancelar</button>'
         '<span class="aviso" id="aviso" hidden></span>')

def barra_html(marca):
    return f'<header class="barra"><span class="marca">{marca}</span>{BOTOES}</header>'

BARRA = barra_html(next(b["html"] for b in BLOCOS if b["tag"] == "h1"))

JS = """
(function () {
  "use strict";
  var TITULO = %TITULO%;
  var FONTES = %FONTES%;
  var BOTOES = %BOTOES%;
  var fonte = document.getElementById("blocos");
  var BLOCOS = JSON.parse(fonte.textContent);
  var principal = document.querySelector("main");
  var btnEditar = document.getElementById("btn-editar");
  var btnSalvar = document.getElementById("btn-salvar");
  var btnCancelar = document.getElementById("btn-cancelar");
  var aviso = document.getElementById("aviso");
  var artefato = null;
  var editando = false;
  var salvando = false;
  var copia = null;

  function renderBloco(b) {
    var cls = b.cls ? ' class="' + b.cls + '"' : "";
    var ed = b.edit ? " data-editavel" : "";
    return "<" + b.tag + ' id="' + b.id + '"' + cls + ed + ">" + b.html +
      "</" + b.tag + ">";
  }

  function barraHtml() {
    var h1 = BLOCOS.filter(function (b) { return b.tag === "h1"; })[0];
    return '<header class="barra"><span class="marca">' +
      (h1 ? h1.html : TITULO) + "</span>" + BOTOES + "</header>";
  }

  function corpo() {
    return BLOCOS.map(renderBloco).join("\\n");
  }

  function json() {
    return JSON.stringify(BLOCOS).replace(/</g, "\\\\u003c");
  }

  // Regenera o documento inteiro a partir do estado, nunca do DOM vivo.
  function documentoCompleto() {
    var css = document.getElementById("estilo").textContent;
    var js = document.getElementById("comportamento").textContent;
    var fim = "<" + "/script>";
    return '<!doctype html>\\n<html lang="pt-BR">\\n<head>\\n' +
      '<meta charset="utf-8">\\n' +
      '<meta name="viewport" content="width=device-width, initial-scale=1, ' +
      'viewport-fit=cover">\\n<title>' + TITULO + "</title>\\n" + FONTES +
      '\\n<style id="estilo">' + css + "</style>\\n</head>\\n<body>\\n" +
      barraHtml() + "\\n<main>\\n" + corpo() + "\\n</main>\\n" +
      '<script type="application/json" id="blocos">' + json() + fim + "\\n" +
      '<script id="comportamento">' + js + fim + "\\n</body>\\n</html>";
  }

  function alvo(el) {
    return el.matches("figure.fig") ? el.querySelector("figcaption") : el;
  }

  function editaveis() {
    return Array.prototype.slice.call(
      principal.querySelectorAll("[data-editavel]"));
  }

  // Tira os atributos que o modo de edição injeta, para que o estado
  // gravado seja o texto e nada mais.
  function limpar(h) {
    return h.replace(/\\s*contenteditable="[^"]*"/g, "")
      .replace(/\\s*spellcheck="[^"]*"/g, "");
  }

  function recolher() {
    BLOCOS.forEach(function (b) {
      if (!b.edit) { return; }
      var el = document.getElementById(b.id);
      if (el) { b.html = limpar(el.innerHTML).trim(); }
    });
    atualizarSumario();
  }

  function atualizarSumario() {
    var item = BLOCOS.filter(function (b) { return b.id === "sumario"; })[0];
    if (!item) { return; }
    var links = BLOCOS.filter(function (b) { return b.tag === "h2"; })
      .map(function (b) {
        return '<li><a href="#' + b.id + '">' + b.html + "</a></li>";
      }).join("");
    item.html = '<div class="label">Sumário</div><ol>' + links + "</ol>";
    var el = document.getElementById("sumario");
    if (el) { el.innerHTML = item.html; }
  }

  function pintar() {
    principal.innerHTML = corpo();
  }

  function mensagem(texto, erro) {
    aviso.textContent = texto || "";
    aviso.hidden = !texto;
    aviso.style.color = erro ? "var(--rust)" : "";
  }

  function barra() {
    btnEditar.hidden = editando || !artefato;
    btnSalvar.hidden = !editando;
    btnCancelar.hidden = !editando;
    btnSalvar.disabled = salvando;
    btnCancelar.disabled = salvando;
  }

  function entrar() {
    copia = JSON.stringify(BLOCOS);
    editando = true;
    document.body.classList.add("modo-edicao");
    editaveis().forEach(function (el) {
      var destino = alvo(el);
      if (destino) {
        destino.setAttribute("contenteditable", "true");
        destino.spellcheck = true;
      }
    });
    barra();
    mensagem("Clique em qualquer texto para editar. As legendas das figuras " +
      "também são editáveis; o código e as saídas do R não. Salvar publica " +
      "uma nova versão desta página para todos que têm o link.");
    var primeiro = editaveis()[0];
    if (primeiro && alvo(primeiro)) { alvo(primeiro).focus(); }
  }

  function sair() {
    editando = false;
    salvando = false;
    document.body.classList.remove("modo-edicao");
    editaveis().forEach(function (el) {
      var destino = alvo(el);
      if (destino) { destino.removeAttribute("contenteditable"); }
    });
    barra();
  }

  btnEditar.addEventListener("click", function () {
    if (artefato) { entrar(); }
  });

  btnCancelar.addEventListener("click", function () {
    if (salvando) { return; }
    BLOCOS = JSON.parse(copia);
    sair();
    pintar();
    mensagem("Edição descartada.");
  });

  btnSalvar.addEventListener("click", function () {
    if (salvando || !artefato) { return; }
    recolher();
    salvando = true;
    barra();
    mensagem("Publicando nova versão...");
    artefato.publish(documentoCompleto()).then(function () {
      salvando = false;
      sair();
      mensagem("Versão publicada. A página recarrega sozinha.");
    }).catch(function (e) {
      salvando = false;
      var codigo = (e && e.code) || "";
      if (codigo === "conflict") {
        mensagem("Outra versão foi publicada enquanto você editava. A " +
          "página vai recarregar com ela; refaça a alteração.", true);
      } else if (codigo === "not_granted" || codigo === "not_writer") {
        artefato = null;
        sair();
        pintar();
        mensagem("Esta visualização não tem permissão para editar a página.",
          true);
        return;
      } else {
        mensagem("Não foi possível publicar" +
          (e && e.message ? ": " + e.message : "."), true);
      }
      barra();
    });
  });

  window.addEventListener("beforeunload", function (e) {
    if (editando && !salvando) { e.preventDefault(); e.returnValue = ""; }
  });

  if (window.claude && typeof window.claude.use === "function") {
    window.claude.use("artifact").then(function (api) {
      artefato = api || null;
      barra();
    }).catch(function () {
      artefato = null;
      barra();
    });
  }
  barra();
}());
"""
JS = (JS.replace("%TITULO%", json.dumps(TITULO))
        .replace("%FONTES%", json.dumps(FONTES))
        .replace("%BOTOES%", json.dumps(BOTOES)))

estado = json.dumps(BLOCOS, ensure_ascii=False).replace("<", "\\u003c")
pagina = (f"<title>{TITULO}</title>\n{FONTES}\n"
          f'<style id="estilo">{CSS}</style>\n'
          f"{BARRA}\n<main>\n{corpo_html}\n</main>\n"
          f'<script type="application/json" id="blocos">{estado}</script>\n'
          f'<script id="comportamento">{JS}</script>\n')
SAIDA_HTML.write_text(pagina, encoding="utf8")

print("md:", SAIDA_MD.stat().st_size, "bytes")
print("html:", SAIDA_HTML.stat().st_size, "bytes | blocos:", len(BLOCOS),
      "| editáveis:", sum(1 for b in BLOCOS if b["edit"]),
      "| seções:", len(titulos), "| imagens:", pagina.count("<img "))
for tag in ["figure", "div", "table", "ul", "ol", "p", "h2", "pre", "nav", "header", "button"]:
    a = len(re.findall(rf"<{tag}[ >]", corpo_html + BARRA)); f = (corpo_html + BARRA).count(f"</{tag}>")
    if a != f: print("DESBALANCEADO:", tag, a, f)
ids = [b["id"] for b in BLOCOS]
assert len(ids) == len(set(ids)), "ids repetidos"
assert "</script>" not in estado and "</script>" not in JS, "fecha script dentro de string"
print("ids únicos e sem </script> embutido: ok")
