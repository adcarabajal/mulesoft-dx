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


# ---------------------------------------------------------------------------
# H4: MCP capability flag keys/values must be HTML-escaped, not |safe-rendered.
# ---------------------------------------------------------------------------

def test_h4_mcp_capability_flag_keys_are_escaped(tmp_path):
    """A capability flag key containing HTML must render as text, not markup."""
    from bs4 import BeautifulSoup

    from tests.fixtures.security import build_mcp_with_xss_capabilities

    html = build_mcp_with_xss_capabilities(tmp_path)
    soup = BeautifulSoup(html, 'html.parser')
    # An <img> with onerror would mean concat-then-|safe leaked through.
    assert soup.find('img') is None
    # The literal `<img src=x onerror=alert(1)>` must appear as escaped text.
    assert '<img src=x onerror=alert(1)>' in soup.get_text()


# ---------------------------------------------------------------------------
# H5: MCP resource mimeType must be passed as a separate (autoescaped) arg,
#     not concatenated into the title-badges HTML string.
# ---------------------------------------------------------------------------

def test_h5_mcp_resource_mimetype_is_escaped():
    """A malicious mimeType must render as text, not markup."""
    from bs4 import BeautifulSoup

    from portal_generator.template_env import create_env

    env = create_env()
    wrapper = env.from_string(
        '{% import "mcp/macros.html" as m %}'
        '{{ m.render_resource(resource, 0) }}'
    )
    html = wrapper.render(resource={
        'name': 'fixture',
        'uri': 'file:///x',
        'description': '',
        'mimeType': '"><script>alert(1)</script>',
    })
    soup = BeautifulSoup(html, 'html.parser')
    assert soup.find('script') is None
    assert '<script>alert(1)</script>' in soup.get_text()


def test_h5_mcp_resource_template_mimetype_is_escaped():
    """Same H5 protection for resource templates."""
    from bs4 import BeautifulSoup

    from portal_generator.template_env import create_env

    env = create_env()
    wrapper = env.from_string(
        '{% import "mcp/macros.html" as m %}'
        '{{ m.render_resource_template(template, 0) }}'
    )
    html = wrapper.render(template={
        'name': 'fixture-template',
        'uriTemplate': 'file:///{x}',
        'description': '',
        'mimeType': '"><script>alert(1)</script>',
    })
    soup = BeautifulSoup(html, 'html.parser')
    assert soup.find('script') is None
    assert '<script>alert(1)</script>' in soup.get_text()
