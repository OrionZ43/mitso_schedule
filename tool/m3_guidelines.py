"""Выгрузка гайдлайнов Material 3 с m3.material.io в markdown.

    python tool/m3_guidelines.py                    # компоненты и стили
    python tool/m3_guidelines.py components/switch  # отдельные страницы

m3.material.io — Angular-приложение, текст в HTML не отдаётся. Скрипт делает то
же, что сайт в браузере:

1. в бандле `main.*.js` лежат версия контента (`carbonVersion`) и карта
   «адрес страницы → exportedCarbonFileId»;
2. страница — `/_dsm/content/m3/<version>/<id>.json`: разделы (вкладки
   Overview / Specs / Guidelines / Accessibility) из блоков текста, картинок
   с подписями и таблиц токенов;
3. таблица токенов — `/_dsm/data/dsdb-m3/<version>/TOKEN_TABLE.<component>.json`.

Результат — `.m3-guidelines/<slug>.md` (папка в .gitignore: это копия чужой
документации, в репозиторий она не попадает). Запросы идут по одному с
паузой, повторно скачанное берётся из `.m3-guidelines/raw`.
"""

from __future__ import annotations

import html
import json
import re
import sys
import time
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

SITE = "https://m3.material.io"
OUT = Path(__file__).resolve().parent.parent / ".m3-guidelines"
RAW = OUT / "raw"
DELAY = 0.4

# Что выгружать по умолчанию: все компоненты, стили и нужные основы.
DEFAULT_PREFIXES = (
    "components/",
    "styles/",
    "foundations/interaction/",
    "foundations/layout/",
    "foundations/building-for-all",
    "foundations/design-tokens",
    "foundations/customization",
    "m3-expressive-motion-theming",
    "building-with-m3-expressive",
)


def fetch(url: str, cache_name: str | None = None) -> bytes:
    if cache_name:
        cached = RAW / cache_name
        if cached.exists():
            return cached.read_bytes()
    request = urllib.request.Request(url, headers={"User-Agent": "m3-guidelines-dump"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    time.sleep(DELAY)
    if cache_name:
        cached.parent.mkdir(parents=True, exist_ok=True)
        cached.write_bytes(data)
    return data


class _Markdown(HTMLParser):
    """Минимальный HTML → markdown: заголовки, абзацы, списки, ссылки, таблицы."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.out: list[str] = []
        self.lists: list[str] = []
        self.href: str | None = None
        self.cell = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if re.fullmatch(r"h[1-6]", tag):
            self.out.append("\n\n" + "#" * (int(tag[1]) + 2) + " ")
        elif tag in ("p", "div"):
            self.out.append("\n\n")
        elif tag == "br":
            self.out.append("\n")
        elif tag in ("ul", "ol"):
            self.lists.append(tag)
        elif tag == "li":
            indent = "  " * (len(self.lists) - 1)
            bullet = "1." if self.lists and self.lists[-1] == "ol" else "-"
            self.out.append(f"\n{indent}{bullet} ")
        elif tag in ("strong", "b"):
            self.out.append("**")
        elif tag in ("em", "i"):
            self.out.append("_")
        elif tag == "code":
            self.out.append("`")
        elif tag == "a":
            self.href = a.get("href")
            self.out.append("[")
        elif tag == "tr":
            self.out.append("\n|")
        elif tag in ("td", "th"):
            self.out.append(" ")

    def handle_endtag(self, tag):
        if tag in ("ul", "ol") and self.lists:
            self.lists.pop()
            self.out.append("\n")
        elif tag in ("strong", "b"):
            self.out.append("**")
        elif tag in ("em", "i"):
            self.out.append("_")
        elif tag == "code":
            self.out.append("`")
        elif tag == "a":
            href = self.href or ""
            if href.startswith("/"):
                href = SITE + href
            self.out.append(f"]({href})")
            self.href = None
        elif tag in ("td", "th"):
            self.out.append(" |")
        elif tag == "table":
            self.out.append("\n")

    def handle_data(self, data):
        self.out.append(data.replace("\xa0", " "))

    def text(self) -> str:
        s = "".join(self.out)
        # <li><p>…</p></li>: абзац внутри пункта не должен отрывать текст от маркера.
        s = re.sub(r"(\n *(?:-|1\.) )\s+", r"\1", s)
        s = re.sub(r"[ \t]+\n", "\n", s)
        s = re.sub(r"\n{3,}", "\n\n", s)
        return s.strip()


def html_to_md(value: str | None) -> str:
    if not value:
        return ""
    parser = _Markdown()
    parser.feed(value)
    return parser.text()


def _color(c: dict) -> str:
    r, g, b = (round(c.get(k, 0) * 255) for k in ("red", "green", "blue"))
    a = c.get("alpha", 1)
    return f"#{r:02X}{g:02X}{b:02X}" + ("" if a == 1 else f" α{a}")


def _literal(value: dict) -> str | None:
    if "tokenName" in value:
        return value["tokenName"]
    if "color" in value:
        return _color(value["color"])
    if "length" in value:
        length = value["length"]
        return f"{length.get('value', 0)}{'dp' if length.get('unit') == 'DIPS' else ' ' + str(length.get('unit'))}"
    for key in ("opacity", "numeric", "fontWeight", "lineHeight", "fontSize", "durationMs"):
        if key in value:
            return f"{key} {value[key]}"
    if "shape" in value:
        shape = value["shape"]
        return json.dumps(shape, ensure_ascii=False)
    if "elevation" in value:
        return f"elevation {value['elevation'].get('value', 0)}dp"
    if "cubicBezier" in value:
        cb = value["cubicBezier"]
        return "cubic-bezier({})".format(", ".join(str(cb.get(k, 0)) for k in ("x0", "y0", "x1", "y1")))
    rest = {k: v for k, v in value.items() if k not in _META}
    return json.dumps(rest, ensure_ascii=False) if rest else None


_META = {"name", "revisionId", "revisionCreateTime", "state", "createTime",
         "revisionAuthor", "contextTags", "specificityScore", "undefined", "tokenName"}


def token_table(version: str, resource: str) -> str:
    component = resource.split("components/")[1]
    data = json.loads(fetch(
        f"{SITE}/_dsm/data/dsdb-m3/{version}/TOKEN_TABLE.{component}.json",
        f"tokens-{component}.json",
    ))["system"]
    tags = {t["name"]: t["displayName"] for t in data.get("tags", [])}
    groups = {g["name"]: g["displayName"] for g in data.get("displayGroups", [])}
    values: dict[str, list[dict]] = {}
    for value in data.get("values", []):
        values.setdefault(value["name"].split("/values/")[0], []).append(value)

    lines: list[str] = []
    current_group = None
    tokens = sorted(
        data.get("tokens", []),
        key=lambda t: (groups.get(t.get("displayGroup"), ""), t.get("orderInDisplayGroup", 0)),
    )
    for token in tokens:
        # Системные и референсные токены (md.sys / md.ref) общие для всех
        # страниц, в таблице компонента они только мешают.
        if not token["tokenName"].startswith("md.comp."):
            continue
        group = groups.get(token.get("displayGroup"), "")
        if group != current_group:
            lines.append(f"\n**{group or 'Tokens'}**\n")
            current_group = group
        rendered = []
        for value in values.get(token["name"], []):
            if value.get("undefined"):
                continue
            literal = _literal(value)
            if literal is None:
                continue
            context = ", ".join(tags[t] for t in value.get("contextTags", []) if t in tags)
            rendered.append(literal + (f" [{context}]" if context else ""))
        lines.append(f"- `{token['tokenName']}` = " + ("; ".join(dict.fromkeys(rendered)) or "—"))
    return "\n".join(lines)


def page_markdown(slug: str, file_id: str, version: str) -> str:
    page = json.loads(fetch(f"{SITE}/_dsm/content/m3/{version}/{file_id}", f"page-{file_id}"))
    parts = [
        f"# {page.get('headerTitle') or page.get('title')}",
        f"Источник: {SITE}/{slug} (контент {version})",
    ]
    if page.get("description"):
        parts.append(html_to_md(page["description"]))

    for section in sorted(page.get("sections", []), key=lambda s: s.get("position", 0)):
        if section.get("isVisible") is False:
            continue
        parts.append(f"\n## {section.get('name') or ''}".rstrip())
        for block in section.get("contentBlocks", []):
            if block.get("isHidden"):
                continue
            if block.get("title"):
                parts.append(f"### {html.unescape(block['title'])}")
            for chunk in block.get("contentChunks", []):
                kind = chunk.get("contentChunkType")
                label = chunk.get("captionModifier") or chunk.get("captionModifierCustomName")
                footer = html_to_md(chunk.get("footer"))
                if kind == "TEXT":
                    parts.append(html_to_md(chunk.get("htmlValue")))
                elif kind in ("IMAGE", "VIDEO"):
                    alt = (chunk.get("altText") or "").strip()
                    text = " — ".join(x for x in (alt, footer) if x)
                    if text or label:
                        media = "Видео" if kind == "VIDEO" else "Изображение"
                        prefix = f"**{label}** " if label else ""
                        parts.append(f"> {prefix}[{media}] {text}")
                elif kind == "RESOURCE" and chunk.get("libraryModuleType") == "TOKEN_TABLE":
                    try:
                        parts.append("### Tokens\n" + token_table(version, chunk["resourceName"]))
                    except Exception as error:  # таблица не критична для текста
                        parts.append(f"> [Таблица токенов не загрузилась: {error}]")
                elif kind == "SNIPPET" and chunk.get("snippetCode"):
                    parts.append(f"```{chunk.get('snippetLanguage') or ''}\n{chunk['snippetCode']}\n```")
                elif footer:
                    parts.append(footer)
    return "\n\n".join(p for p in parts if p).strip() + "\n"


def main(argv: list[str]) -> None:
    index_html = fetch(SITE + "/").decode("utf-8")
    bundle = re.search(r'src="(/static/angular/main\.[0-9a-f]+\.js)"', index_html)
    if not bundle:
        sys.exit("Не найден main.*.js — вёрстка сайта поменялась")
    js = fetch(SITE + bundle.group(1)).decode("utf-8")
    version = re.search(r'carbonVersion:"([^"]+)"', js).group(1)
    routes = dict(re.findall(r'\{"slug":"([^"]+)","exportedCarbonFileId":"([^"]+)"', js))

    wanted = argv or [s for s in routes if s.startswith(DEFAULT_PREFIXES)]
    OUT.mkdir(parents=True, exist_ok=True)
    index = [f"# Гайдлайны Material 3 (m3.material.io, контент {version})\n"]
    for slug in wanted:
        if slug not in routes:
            print(f"нет страницы: {slug}", file=sys.stderr)
            continue
        target = OUT / (slug.replace("/", "__") + ".md")
        target.write_text(page_markdown(slug, routes[slug], version), encoding="utf-8")
        index.append(f"- [{slug}]({target.name}) — {SITE}/{slug}")
        print(slug)
    if not argv:
        (OUT / "index.md").write_text("\n".join(index) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1:])
