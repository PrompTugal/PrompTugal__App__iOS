"""A small Markdown-to-HTML renderer for the briefs. Standard library only.

Covers what the briefs use, and nothing more: ATX headings (with ids), paragraphs,
bullet and numbered lists (one level, plus indented continuation lines),
GitHub-style tables, fenced code, block quotes, horizontal rules, and the inline
forms `code`, **strong**, *em* and [text](href). All text is HTML-escaped.
Anything else is passed through as text, never as HTML.

`render(text, link=fn)` lets the caller rewrite every link target.
"""
import html
import re

INLINE = re.compile(r'`([^`]+)`|\*\*(.+?)\*\*|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])|\[([^\]]+)\]\(([^)\s]+)\)')


def slugify(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-') or 'section'


def inline(text, link=lambda href: href):
    out, pos = [], 0
    for m in INLINE.finditer(text):
        out.append(html.escape(text[pos:m.start()], quote=False))
        code, strong, em, label, href = m.groups()
        if code is not None:
            out.append(f'<code>{html.escape(code, quote=False)}</code>')
        elif strong is not None:
            out.append(f'<strong>{inline(strong, link)}</strong>')
        elif em is not None:
            out.append(f'<em>{inline(em, link)}</em>')
        else:
            out.append(f'<a href="{html.escape(link(href))}">{inline(label, link)}</a>')
        pos = m.end()
    out.append(html.escape(text[pos:], quote=False))
    return ''.join(out)


def _cells(row):
    row = row.strip()
    if row.startswith('|'):
        row = row[1:]
    if row.endswith('|'):
        row = row[:-1]
    return [c.strip() for c in re.split(r'(?<!\\)\|', row)]


def render(text, link=lambda href: href):
    lines = text.replace('\r\n', '\n').split('\n')
    out, i, ids = [], 0, set()
    para = []

    def flush():
        if para:
            out.append(f'<p>{inline(" ".join(para), link)}</p>')
            para.clear()

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            flush()
            i += 1
        elif stripped.startswith('```'):
            flush()
            lang = stripped[3:].strip()
            body, i = [], i + 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                body.append(lines[i])
                i += 1
            cls = f' class="language-{html.escape(lang)}"' if lang else ''
            out.append(f'<pre><code{cls}>{html.escape(chr(10).join(body), quote=False)}</code></pre>')
            i += 1
        elif m := re.match(r'(#{1,4})\s+(.*)', stripped):
            flush()
            level, title = len(m.group(1)), m.group(2).strip()
            anchor, n = slugify(title), 2
            while anchor in ids:
                anchor, n = f'{slugify(title)}-{n}', n + 1
            ids.add(anchor)
            out.append(f'<h{level} id="{anchor}">{inline(title, link)}</h{level}>')
            i += 1
        elif re.fullmatch(r'(-{3,}|\*{3,})', stripped):
            flush()
            out.append('<hr>')
            i += 1
        elif stripped.startswith('>'):
            flush()
            quote = []
            while i < len(lines) and lines[i].strip().startswith('>'):
                quote.append(lines[i].strip()[1:].strip())
                i += 1
            out.append(f'<blockquote>{render(chr(10).join(quote), link)}</blockquote>')
        elif stripped.startswith('|') and i + 1 < len(lines) and re.fullmatch(r'\|?[\s:|-]+\|?', lines[i + 1].strip()) and '-' in lines[i + 1]:
            flush()
            head = _cells(stripped)
            rows, i = [], i + 2
            while i < len(lines) and lines[i].strip().startswith('|'):
                rows.append(_cells(lines[i]))
                i += 1
            th = ''.join(f'<th scope="col">{inline(c, link)}</th>' for c in head)
            body = ''.join('<tr>' + ''.join(f'<td>{inline(c, link)}</td>' for c in r) + '</tr>' for r in rows)
            out.append(f'<div class="table-wrap"><table><thead><tr>{th}</tr></thead><tbody>{body}</tbody></table></div>')
        elif m := re.match(r'(\s*)([-*]|\d+\.)\s+(.*)', line):
            flush()
            ordered = m.group(2)[0].isdigit()
            items = []
            while i < len(lines):
                m = re.match(r'(\s*)([-*]|\d+\.)\s+(.*)', lines[i])
                if m and m.group(2)[0].isdigit() == ordered:
                    items.append([m.group(3)])
                    i += 1
                elif items and lines[i].startswith(('  ', '\t')) and lines[i].strip():
                    items[-1].append(lines[i].strip())
                    i += 1
                else:
                    break
            tag = 'ol' if ordered else 'ul'
            out.append(f'<{tag}>' + ''.join(f'<li>{inline(" ".join(it), link)}</li>' for it in items) + f'</{tag}>')
        else:
            para.append(stripped)
            i += 1
    flush()
    return '\n'.join(out)


def title_and_summary(text):
    """A brief's title is its first `# ` heading; its summary is the first `> ` line."""
    title = re.search(r'^#\s+(.+)$', text, re.M)
    summary = re.search(r'^>\s+(.+)$', text, re.M)
    if not title or not summary:
        raise SystemExit('markdown: a brief needs a "# Title" line and a "> summary" line')
    plain = lambda s: re.sub(r'[`*]|\[([^\]]+)\]\([^)]+\)', r'\1', s).strip()
    return plain(title.group(1)), plain(summary.group(1))
