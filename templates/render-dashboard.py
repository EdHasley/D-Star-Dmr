#!/usr/bin/env python3
"""Fill dashboard settings as escaped PHP literals, preserving the dashboard template."""
import re
import sys
from pathlib import Path

def php_string(value):
    return "'" + value.replace('\\', '\\\\').replace("'", "\\'") + "'"

def render(path, email, header, footer, country, comment, interface, modules, domain):
    modules = int(modules)
    if not 1 <= modules <= 26:
        raise ValueError('Module count must be 1–26')
    values = {
        "$PageOptions['ContactEmail']": php_string(email),
        "$PageOptions['CustomTXT']": php_string(header),
        "$PageOptions['Footnote']": php_string(footer),
        "$PageOptions['NumberOfModules']": str(modules),
        "$CallingHome['Country']": php_string(country),
        "$CallingHome['Comment']": php_string(comment),
        "$CallingHome['MyDashBoardURL']": php_string('http://' + domain),
        "$VNStat['Interfaces'][0]['Name']": php_string(interface),
        "$VNStat['Interfaces'][0]['Address']": php_string(interface),
    }
    config = Path(path)
    text = config.read_text()
    for key, value in values.items():
        pattern = r'(^' + re.escape(key) + r'\s*=\s*).*?;'
        text, count = re.subn(pattern, lambda m: m[1] + value + ';', text, flags=re.MULTILINE)
        if count != 1:
            raise ValueError('Missing or repeated dashboard setting: ' + key)
    config.write_text(text)

if __name__ == '__main__':
    render(*sys.argv[1:])
