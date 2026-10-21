#!/usr/bin/env python3
"""Check the small, dependency-free Pages site before deployment."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

root = Path(__file__).resolve().parents[1] / "site"
class Check(HTMLParser):
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        assert tag not in {"script", "iframe", "form"}, f"Unexpected active content in {page}"
        for name in ("href", "src"):
            value = attrs.get(name, "")
            if value.startswith("/dexduo/"):
                target = root / urlsplit(value).path.removeprefix("/dexduo/")
                if value.endswith("/"): target /= "index.html"
                assert target.is_file(), f"Broken link: {value} in {page}"
        if tag == "link" and attrs.get("rel") == "stylesheet":
            assert attrs.get("href", "").startswith("/dexduo/"), "Styles must be hosted locally"
for page in root.rglob("*.html"):
    text = page.read_text()
    assert '<html lang="en">' in text and '<meta name="viewport"' in text
    assert "kuharharshul@gmail.com" in text
    Check().feed(text)
assert len(list(root.rglob("*.html"))) == 4
print("Four static pages: internal links, metadata and no active third-party content verified.")
