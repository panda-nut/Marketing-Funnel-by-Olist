from __future__ import annotations

import sys
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = BASE_DIR / "olist_project" / "NOTES" / "business_findings.md"


def build_html_document(title: str, body_html: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <style>
    :root {{
      --bg: #f5efe6;
      --paper: rgba(255, 255, 255, 0.92);
      --ink: #1f2937;
      --muted: #5b6472;
      --line: #dfd4c5;
      --accent: #b45309;
      --accent-soft: #fff4e6;
      --code-bg: #fbf7f1;
      --shadow: 0 22px 70px rgba(86, 63, 36, 0.14);
    }}
    * {{
      box-sizing: border-box;
    }}
    body {{
      margin: 0;
      padding: 48px 20px;
      font-family: "Microsoft YaHei", "PingFang SC", "Segoe UI", sans-serif;
      line-height: 1.8;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(255, 255, 255, 0.78), transparent 32%),
        linear-gradient(180deg, #f7f2ea 0%, var(--bg) 100%);
    }}
    main {{
      max-width: 920px;
      margin: 0 auto;
      padding: 44px 52px;
      background: var(--paper);
      border: 1px solid rgba(223, 212, 197, 0.9);
      border-radius: 24px;
      box-shadow: var(--shadow);
      backdrop-filter: blur(6px);
    }}
    h1, h2, h3 {{
      line-height: 1.3;
      margin-top: 1.7em;
      margin-bottom: 0.7em;
      color: #1b1b1b;
    }}
    h1 {{
      margin-top: 0;
      padding-bottom: 16px;
      font-size: 2rem;
      border-bottom: 2px solid var(--line);
      letter-spacing: 0.01em;
    }}
    h2 {{
      font-size: 1.45rem;
      padding-left: 14px;
      border-left: 5px solid var(--accent);
    }}
    h3 {{
      font-size: 1.15rem;
    }}
    p {{
      margin: 0.85em 0;
    }}
    strong {{
      color: #111827;
    }}
    ul, ol {{
      margin: 0.85em 0 1.1em;
      padding-left: 1.45em;
    }}
    li {{
      margin: 0.4em 0;
    }}
    a {{
      color: var(--accent);
      text-decoration: none;
      border-bottom: 1px solid rgba(180, 83, 9, 0.25);
    }}
    a:hover {{
      border-bottom-color: var(--accent);
    }}
    pre, .codehilite {{
      background: var(--code-bg);
      padding: 16px 18px;
      overflow-x: auto;
      border-radius: 14px;
      border: 1px solid #eadfce;
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.6);
    }}
    code {{
      padding: 0.15em 0.4em;
      background: var(--accent-soft);
      border-radius: 6px;
      font-family: Consolas, "Courier New", monospace;
      font-size: 0.95em;
    }}
    pre code, .codehilite code {{
      padding: 0;
      background: transparent;
      border-radius: 0;
    }}
    blockquote {{
      margin: 1.2em 0;
      padding: 0.8em 1em;
      color: var(--muted);
      background: #fffaf3;
      border-left: 4px solid #d6b58b;
      border-radius: 0 12px 12px 0;
    }}
    table {{
      border-collapse: collapse;
      width: 100%;
      margin: 1.2em 0;
      overflow: hidden;
      border-radius: 14px;
      background: #fffdfa;
      border: 1px solid #eadfce;
    }}
    th, td {{
      border: 1px solid #eee4d8;
      padding: 10px 14px;
      text-align: left;
    }}
    th {{
      background: #f8eedf;
      color: #5b3a12;
    }}
    hr {{
      border: none;
      height: 1px;
      margin: 2em 0;
      background: linear-gradient(90deg, transparent, var(--line), transparent);
    }}
    ::selection {{
      background: #fde2b6;
    }}
    @media (max-width: 768px) {{
      body {{
        padding: 20px 12px;
      }}
      main {{
        padding: 28px 20px;
        border-radius: 18px;
      }}
      h1 {{
        font-size: 1.6rem;
      }}
      h2 {{
        font-size: 1.25rem;
      }}
    }}
    @media print {{
      body {{
        background: #fff;
        padding: 0;
      }}
      main {{
        max-width: none;
        margin: 0;
        padding: 0;
        border: none;
        border-radius: 0;
        box-shadow: none;
        background: #fff;
      }}
      a {{
        color: inherit;
        border-bottom: none;
      }}
    }}
  </style>
</head>
<body>
  <main>
{body_html}
  </main>
</body>
</html>
"""


def convert_markdown_to_html(input_path: Path, output_path: Path) -> None:
    try:
        import markdown
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "缺少 markdown 库，请先运行: pip install markdown"
        ) from exc

    markdown_text = input_path.read_text(encoding="utf-8")
    body_html = markdown.markdown(
        markdown_text,
        extensions=["extra", "codehilite", "tables", "toc"],
    )
    full_html = build_html_document(input_path.stem, body_html)
    output_path.write_text(full_html, encoding="utf-8")


def main() -> None:
    input_path = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else DEFAULT_INPUT
    if not input_path.is_absolute():
        input_path = (Path.cwd() / input_path).resolve()

    output_path = (
        Path(sys.argv[2]).expanduser()
        if len(sys.argv) > 2
        else input_path.with_suffix(".html")
    )
    if not output_path.is_absolute():
        output_path = (Path.cwd() / output_path).resolve()

    if not input_path.exists():
        raise SystemExit(f"找不到 Markdown 文件: {input_path}")

    convert_markdown_to_html(input_path, output_path)
    print(f"转换完成: {input_path} -> {output_path}")


if __name__ == "__main__":
    main()
