"""Security-regression tests for the portal generator.

Every test here corresponds to an audit finding ID. Test names embed the ID so
grep `audit ID -> test` is one-shot.
"""

import json

import pytest

from portal_generator.template_env import _tojson_raw


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
