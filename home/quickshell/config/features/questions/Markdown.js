.pragma library
.import "vendor/Marked.js" as Vendor

// Converts model-written Markdown to the HTML subset Qt rich text understands.
// Raw HTML and images are never passed through: only text, http(s) links and
// our own table-based cards reach the TextEdit, so nothing is fetched or executed.

function escapeHtml(text) {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

// Qt rich text has no block padding or margin collapsing, so cards sit between small spacer paragraphs.
function spacer(px) {
  return '<p style="margin:0; font-size:' + px + 'px">&nbsp;</p>'
}

function toHtml(markdown, style) {
  const marked = Vendor.api()
  const parser = new marked.Marked({
    gfm: true,
    renderer: {
      html: token => escapeHtml(token.text),
      image: token => escapeHtml(token.text),
      link(token) {
        const inner = this.parser.parseInline(token.tokens)
        return /^https?:\/\//i.test(token.href) ? '<a href="' + escapeHtml(token.href) + '">' + inner + "</a>" : inner
      },
      heading(token) {
        const marker = token.depth > 1 ? '<span style="color:' + style.accent + '">\u258D</span>&nbsp;' : ""
        return "<h" + token.depth + ">" + marker + this.parser.parseInline(token.tokens) + "</h" + token.depth + ">"
      },
      // The inline lexer already escapes code span text.
      codespan: token => '<span style="background-color:' + style.chipBackground + "; color:" + style.chipForeground + '">&nbsp;' + token.text + "&nbsp;</span>",
      code: token => spacer(4) + '<table width="100%" cellspacing="0" cellpadding="12" bgcolor="' + style.codeBackground
        + '"><tr><td valign="top"><pre style="margin:0; color:' + style.codeForeground + '">' + escapeHtml(token.text.replace(/\n+$/, ""))
        + "</pre></td></tr></table>" + spacer(2),
      // Qt paints a cell background only behind its content, never its padding. The outer table's own background
      // is the accent colour, so an empty cell becomes a full-height bar; the inner table paints the padded card.
      blockquote(token) {
        return spacer(4) + '<table width="100%" cellspacing="0" cellpadding="0" bgcolor="' + style.accent + '"><tr><td width="4"></td><td>'
          + '<table width="100%" cellspacing="0" cellpadding="12" bgcolor="' + style.calloutBackground + '"><tr><td valign="top" style="color:'
          + style.calloutForeground + '">' + this.parser.parse(token.tokens) + "</td></tr></table></td></tr></table>" + spacer(2)
      },
      // Ordered items get a numbered chip; unordered lists keep Qt's native bullets.
      list(token) {
        if (!token.ordered) {
          const items = token.items.map(item => "<li>" + this.parser.parse(item.tokens) + "</li>").join("")
          return "<ul>" + items + "</ul>"
        }
        const start = token.start === "" ? 1 : token.start
        const rows = token.items.map((item, index) => '<tr><td valign="top" width="34"><span style="background-color:' + style.chipBackground
          + "; color:" + style.chipForeground + '">&nbsp;' + (start + index) + '&nbsp;</span></td><td valign="top">'
          + this.parser.parse(item.tokens) + "</td></tr>").join("")
        return '<table width="100%" cellspacing="0" cellpadding="3">' + rows + "</table>"
      }
    }
  })
  // Cards and numbered lists carry valign/width attributes, so these patterns match only marked's own tables.
  const body = parser.parse(markdown)
    .replace(/<table>/g, spacer(4) + '<table border="1" cellspacing="0" cellpadding="8" style="border-color:' + style.rule + '; border-collapse:collapse">')
    .replace(/<\/table>/g, "</table>" + spacer(2))
    .replace(/<th>/g, '<th align="left">')
  const css = "a { color:" + style.link + "; text-decoration:underline }"
    + "th { color:" + style.chipForeground + " }"
    + "h1 { font-size:" + Math.round(style.size * 1.5) + "px; font-weight:700; margin-top:8px; margin-bottom:8px }"
    + "h2 { font-size:" + Math.round(style.size * 1.3) + "px; font-weight:700; margin-top:8px; margin-bottom:8px }"
    + "h3 { font-size:" + Math.round(style.size * 1.12) + "px; font-weight:700; margin-top:8px; margin-bottom:6px }"
    + "h4, h5, h6 { font-size:" + style.size + "px; font-weight:700 }"
    + "p { margin-top:0; margin-bottom:10px }"
    + "li { margin-bottom:4px }"
  return "<style>" + css + "</style>" + body
}
