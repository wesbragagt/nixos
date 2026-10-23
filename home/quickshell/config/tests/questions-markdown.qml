import QtQuick
import Quickshell
import "../features/questions/Markdown.js" as Markdown
ShellRoot {
  readonly property var style: ({
    size: 15, background: "#172238", link: "#89b4fa", accent: "#cba6f7", rule: "#304161",
    chipBackground: "#1f2d4d", chipForeground: "#89b4fa", codeBackground: "#101827", codeForeground: "#a6d5bc",
    calloutBackground: "#1c2340", calloutForeground: "#c5cfec", tableHeader: "#1f2d4d"
  })
  TestHarness {
    id: t
    steps: [
      () => {
        const hostile = Markdown.toHtml("<script>alert(1)</script>\n\nplain <b>raw</b> text\n\n![pixel](https://example.com/p.png)\n\n"
          + "[bad](javascript:alert(1)) [file](file:///etc/passwd) [good](https://doc.qt.io/)", style)
        t.verify(hostile.indexOf("<script") < 0 && hostile.indexOf("<b>raw") < 0, "raw HTML is escaped")
        t.verify(hostile.indexOf("<img") < 0 && hostile.indexOf("p.png") < 0, "images never reach rich text")
        t.verify(hostile.indexOf("pixel") >= 0, "image alt text stays readable")
        t.verify(hostile.indexOf("javascript:") < 0 && hostile.indexOf("file:") < 0, "non-HTTP(S) links are dropped")
        t.verify(hostile.indexOf('href="https://doc.qt.io/"') >= 0, "HTTP(S) links survive")
        const quoted = Markdown.toHtml("> <img src=x onerror=1>\n\n```\n<b>code</b> & more\n```", style)
        t.verify(quoted.indexOf("<img") < 0 && quoted.indexOf("&lt;b&gt;code&lt;/b&gt; &amp; more") >= 0, "quotes and code blocks escape markup")
      },
      () => {
        const html = Markdown.toHtml("3. third\n4. fourth\n\n| a | b |\n|---|---|\n| 1 | 2 |", style)
        t.verify(html.indexOf("&nbsp;3&nbsp;") >= 0 && html.indexOf("&nbsp;4&nbsp;") >= 0, "ordered lists keep their start number")
        t.verify(html.indexOf('<th align="left">') >= 0, "table headers are left aligned")
      }
    ]
  }
}
