#!/usr/bin/env python3

"""
CGI script to render Board minutes with HTML anchors
"""
import os
import os.path
import sys
import re

sys.path.append('/srv/whimsy/tools')
import boardminutes2html

# Where to find minutes (locally to Whimsy)
MINUTES_TXT = '/srv/svn/minutes'
MINUTES_HTTPS = 'https://www.apache.org/foundation/records/minutes'

HEAD = """<head>
<meta charset="UTF-8">
</head>
<body>"""

TAIL = """<p>Generated dynamically by Whimsy</p>
</body>
</html>"""

MINUTES_RE = r'board_minutes_\d\d\d\d_\d\d_\d\d\.txt'

def minutes(path):
    """Return sorted list of minute base names"""
    for file in sorted(os.listdir(path)):
        if (re.fullmatch(MINUTES_RE, file)
            and os.path.isfile(os.path.join(path, file))):
            yield file

def year_index(year):
    """Generate year index"""
    if not re.fullmatch(r'\d\d\d\d', year):
        print(f"Invalid year: {year}")
        return
    folder = os.path.join(MINUTES_TXT, year)
    if not os.path.isdir(folder):
        print(f"Could not read directory: {year}")
        return
    print(HEAD)
    print(f'<h1>Board minutes: index of {year}</h1>')
    for minute in minutes(folder):
        print(f"<a href='{year}/{minute}'>{minute}</a><br>")
    print(TAIL)

def top_index():
    """Generate index of years"""
    print(HEAD)
    print('<h1>Board minutes: index of years</h1>')
    for folder in sorted(os.listdir(MINUTES_TXT)):
        if re.fullmatch(r'\d\d\d\d', folder):
            print(f"<a href='{folder}'>{folder}</a>")
    print(TAIL)

def main():
    """Handle HTTP requests"""

    print("Content-type: text/html\n\n")

    try:
        info = os.environ['PATH_INFO']
        parts = info.lstrip('/').split('/')
        if parts[-1] == '': # drop trailing empty part
            parts.pop()
        # Route the request
        if len(parts) == 0:
            top_index()
        elif len(parts) == 1:
            year_index(parts[0])
        elif len(parts) == 2:
            year = parts[0]
            basename = parts[1]
            if not re.fullmatch(MINUTES_RE, basename):
                print("Invalid request")
                return
            source = os.path.join(MINUTES_TXT, year, basename)
            if not os.path.exists(source):
                print(f"No such file as {source}")
                return
            with open(source, encoding='utf8') as inp:
                extrahdr = f"""Links: <a href="../{year}">{year}</a> - <a href="../">All years</a>
- <a href="{MINUTES_HTTPS}/{year}/{basename}" target="_blank">Original</a>"""
                boardminutes2html.text2html(inp, sys.stdout, extrahdr)
        else:
            print(f"Invalid request {parts} {len(parts)}")
    except Exception as ex:
        print(ex)

if __name__ == '__main__':
    main()
