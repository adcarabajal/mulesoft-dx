"""Security-regression tests for the portal generator.

Every test here corresponds to an audit finding ID. Test names embed the ID so
grep `audit ID -> test` is one-shot.
"""

import json
from pathlib import Path

import pytest

from portal_generator.parsers.terraform_parser import parse_terraform_doc
from portal_generator.template_env import _render_markdown, _tojson_raw


# ---------------------------------------------------------------------------
# C2: tojson_raw must HTML-escape unsafe sequences for inline <script> embedding.
# ---------------------------------------------------------------------------

def test_c2_tojson_raw_escapes_script_breakout():
    payload = {'desc': '</script><img src=x onerror=alert(1)>'}
    out = str(_tojson_raw(payload))
    assert '</script>' not in out
    assert '\\u003c/script\\u003e' in out or '\\u003c/script' in out


def test_c2_tojson_raw_escapes_html_entities():
    payload = {'a': '<', 'b': '>', 'c': '&'}
    out = str(_tojson_raw(payload))
    assert '<' not in out and '>' not in out
    assert '"a": "\\u003c"' in out
    assert '"b": "\\u003e"' in out
    assert '"c": "\\u0026"' in out


def test_c2_tojson_raw_escapes_unicode_line_separators():
    payload = {'sep': '  '}
    out = str(_tojson_raw(payload))
    assert ' ' not in out
    assert ' ' not in out
    assert '\\u2028' in out
    assert '\\u2029' in out


def test_c2_tojson_raw_preserves_normal_strings():
    payload = {'name': 'Hello, world!', 'num': 42}
    out = str(_tojson_raw(payload))
    assert json.loads(out) == payload


# ---------------------------------------------------------------------------
# C3: javascript:, data:, vbscript: URL schemes must be neutralized.
# L1: noopener on every generated anchor.
# ---------------------------------------------------------------------------

def test_c3_safe_link_blocks_javascript_scheme():
    out = str(_render_markdown('[click](javascript:alert(1))'))
    assert 'javascript:' not in out
    assert 'href="#"' in out


def test_c3_safe_link_blocks_data_scheme():
    out = str(_render_markdown('[click](data:text/html,<script>alert(1)</script>)'))
    assert 'data:' not in out
    assert 'href="#"' in out


def test_c3_safe_link_blocks_vbscript_scheme():
    out = str(_render_markdown('[click](vbscript:msgbox)'))
    assert 'vbscript:' not in out
    assert 'href="#"' in out


def test_c3_safe_link_allows_https():
    out = str(_render_markdown('[click](https://example.com/page)'))
    assert 'href="https://example.com/page"' in out


def test_c3_safe_link_allows_http():
    out = str(_render_markdown('[click](http://example.com/)'))
    assert 'href="http://example.com/"' in out


def test_c3_safe_link_allows_mailto():
    out = str(_render_markdown('[click](mailto:user@example.com)'))
    assert 'href="mailto:user@example.com"' in out


def test_c3_safe_link_allows_anchor():
    out = str(_render_markdown('[click](#section)'))
    assert 'href="#section"' in out


def test_c3_safe_link_allows_relative_paths():
    for url in ['/abs/path', './rel/path', '../up/path']:
        out = str(_render_markdown(f'[x]({url})'))
        assert f'href="{url}"' in out


def test_l1_safe_link_adds_noopener():
    out = str(_render_markdown('[click](https://example.com/)'))
    assert 'rel="noopener"' in out


# ---------------------------------------------------------------------------
# C4: Terraform parser must strip raw HTML embedded in markdown bodies.
# ---------------------------------------------------------------------------

def test_c4_terraform_parser_strips_raw_html():
    fixture = Path(__file__).parent / 'fixtures' / 'security' / 'malicious_terraform' / 'dangerous.md'
    doc = parse_terraform_doc(fixture)
    assert doc is not None
    body = doc['body_html']
    assert '<script>' not in body
    assert '<iframe' not in body
    # Table syntax must still work — table extension is independent of html: True.
    assert '<table>' in body
