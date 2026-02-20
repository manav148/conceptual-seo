#!/usr/bin/env bash
# Markdown to HTML converter for WordPress content
# Tries multiple methods in order of preference: pandoc, python, node

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
  # Read from stdin if no file argument
  INPUT_FILE=$(mktemp)
  cat > "$INPUT_FILE"
  CLEANUP_INPUT=true
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "ERROR: File not found: $INPUT_FILE" >&2
  exit 1
fi

# Method 1: pandoc (best quality)
if command -v pandoc &>/dev/null; then
  pandoc -f markdown -t html --wrap=none "$INPUT_FILE"
  [ "$CLEANUP_INPUT" = true ] && rm -f "$INPUT_FILE"
  exit 0
fi

# Method 2: Python markdown module
if command -v python3 &>/dev/null; then
  python3 -c "
import sys
try:
    import markdown
    with open(sys.argv[1], 'r') as f:
        print(markdown.markdown(f.read(), extensions=['tables', 'fenced_code', 'codehilite', 'toc', 'nl2br']))
except ImportError:
    # Fallback: basic regex conversion
    import re
    with open(sys.argv[1], 'r') as f:
        text = f.read()
    # Headers
    text = re.sub(r'^######\s+(.+)$', r'<h6>\1</h6>', text, flags=re.MULTILINE)
    text = re.sub(r'^#####\s+(.+)$', r'<h5>\1</h5>', text, flags=re.MULTILINE)
    text = re.sub(r'^####\s+(.+)$', r'<h4>\1</h4>', text, flags=re.MULTILINE)
    text = re.sub(r'^###\s+(.+)$', r'<h3>\1</h3>', text, flags=re.MULTILINE)
    text = re.sub(r'^##\s+(.+)$', r'<h2>\1</h2>', text, flags=re.MULTILINE)
    text = re.sub(r'^#\s+(.+)$', r'<h1>\1</h1>', text, flags=re.MULTILINE)
    # Bold and italic
    text = re.sub(r'\*\*\*(.+?)\*\*\*', r'<strong><em>\1</em></strong>', text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\*(.+?)\*', r'<em>\1</em>', text)
    # Code blocks
    text = re.sub(r'\`\`\`(\w*)\n(.*?)\`\`\`', r'<pre><code>\2</code></pre>', text, flags=re.DOTALL)
    text = re.sub(r'\`(.+?)\`', r'<code>\1</code>', text)
    # Links and images
    text = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', r'<img src=\"\2\" alt=\"\1\">', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href=\"\2\">\1</a>', text)
    # Unordered lists
    text = re.sub(r'^[\-\*]\s+(.+)$', r'<li>\1</li>', text, flags=re.MULTILINE)
    text = re.sub(r'(<li>.*</li>\n?)+', lambda m: '<ul>\n' + m.group(0) + '</ul>\n', text)
    # Ordered lists
    text = re.sub(r'^\d+\.\s+(.+)$', r'<li>\1</li>', text, flags=re.MULTILINE)
    # Horizontal rules
    text = re.sub(r'^---+$', r'<hr>', text, flags=re.MULTILINE)
    # Blockquotes
    text = re.sub(r'^>\s+(.+)$', r'<blockquote>\1</blockquote>', text, flags=re.MULTILINE)
    # Paragraphs - wrap remaining loose text
    lines = text.split('\n')
    result = []
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith('<'):
            result.append(f'<p>{stripped}</p>')
        else:
            result.append(line)
    print('\n'.join(result))
" "$INPUT_FILE"
  [ "$CLEANUP_INPUT" = true ] && rm -f "$INPUT_FILE"
  exit 0
fi

# Method 3: Node.js with marked
if command -v node &>/dev/null; then
  node -e "
const fs = require('fs');
try {
  const marked = require('marked');
  const md = fs.readFileSync(process.argv[1], 'utf8');
  console.log(marked.parse(md));
} catch(e) {
  // Fallback: very basic conversion
  let md = fs.readFileSync(process.argv[1], 'utf8');
  md = md.replace(/^### (.+)$/gm, '<h3>\$1</h3>');
  md = md.replace(/^## (.+)$/gm, '<h2>\$1</h2>');
  md = md.replace(/^# (.+)$/gm, '<h1>\$1</h1>');
  md = md.replace(/\*\*(.+?)\*\*/g, '<strong>\$1</strong>');
  md = md.replace(/\*(.+?)\*/g, '<em>\$1</em>');
  md = md.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href=\"\$2\">\$1</a>');
  console.log(md);
}
" "$INPUT_FILE"
  [ "$CLEANUP_INPUT" = true ] && rm -f "$INPUT_FILE"
  exit 0
fi

echo "ERROR: No markdown converter found. Install pandoc, python3, or node." >&2
exit 1
