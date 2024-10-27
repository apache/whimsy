#!/usr/bin/env python3

"""
Convert board minutes to HTML with anchors and index

Processes minutes to add the following:
- anchors for internal sections
- links to internal sections
- links to external http(s) URLs
- links to board_minute references
- index to sections (excluding committee report sections which are just references)

N.B. The naming convention for internal anchors is:
     section-xx or attachment-xx
These anchors are intended to be referenced externally, so the format must not be changed
"""

import sys
import re
from html import escape

MINUTES = 'https://www.apache.org/foundation/records/minutes/'

def pod_anchor(podling):
    """convert podling name to anchor"""
    return podling.strip().lower().replace(' ', '')

#  <a class="selflink" id="section-10" href="#section-10">10</a>
def add_anchor(current_s, line, links, info):
    """Add anchors"""
    # main section
    mat = re.match(r'^([ \d]\d)(\. .+)', line)
    if mat:
        sect = mat.group(1)
        off = ''
        if sect.startswith(' '):
            off = ''
        sid = sect.replace(' ','')
        rest = mat.group(2)
        sname = f"section-{sid}"
        line = f'{off}<a class="selflink" id="{sname}" href="#{sname}">{sid}{rest}</a>\n'
        links[sname] = rest.lstrip('. ')
        # flag when in committee reports
        if 'Committee Reports' in rest:
            info['crsection'] = sid
        else:
            info.pop('crsection', None)
        return sid, line # return the updated section number

    # subsections
    mat = re.match(r'^( {3,4})([A-Z]+)(\. .+)', line)
    if mat:
        off = mat.group(1)
        sect = mat.group(2)
        sid = current_s + sect.lstrip(' ')
        sname = f"section-{sid}"
        rest = mat.group(3)
        line = f'{off}<a class="selflink" id="{sname}" href="#{sname}">{sect}{rest}</a>\n'
        links[sname] = rest.lstrip('. ')
        return current_s, line

    # Attachments
    mat = re.match(r'^Attachment (\w+)(: .+)', line)
    if mat:
        sect = mat.group(1)
        sname = 'attachment-' + sect
        rest = mat.group(2)
        info['sname'] = rest
        line = f'<a class="selflink" id="{sname}" href="#{sname}">Attachment {sect}{rest}</a>\n'
        links[sname] = rest.lstrip(':')
        return current_s, line

    # Links to attachments
    mat = re.match(r'^ +(See Attachment (\w+))', line)
    if mat:
        ref = mat.group(1)
        sect = mat.group(2)
        line = line.replace(ref, f'<a href="#attachment-{sect}">{ref}</a>')
        # drop link to CR section if there is an attachment
        crsect = info.get('crsection')
        if crsect:
            links.pop(f'section-{crsect}{sect}')
        return current_s, line

    # board minutes
    mat = re.search(r' (board_minutes_(\d\d\d\d)_\d\d_\d\d.txt)', line)
    if mat:
        minutes = mat.group(1)
        year = mat.group(2)
        line = line.replace(minutes, f'<a href="{MINUTES}{year}/{minutes}">{minutes}</a>')
        return current_s, line

    # external URLs TODO: tighten matching ..
    mat = re.search(r'(https?://[^\s,)]+)', line)
    if mat:
        url = mat.group(1).rstrip(".")
        line = line.replace(url, f'<a href="{url}">{url}</a>')
        return current_s, line

    # Podling ToC?
    # [Podling](#podling)
    mat = re.match(r'\[[^]]+\]\((#[^)]+)\)', line)
    if mat:
        anchor = mat.group(1)
        line = line.replace(anchor, f'<a href="{pod_anchor(anchor)}">{anchor}</a>')
        return current_s, line

    # we are in a podling report
    if info['podhdr'] and line.strip() != '':
        info['podhdr'] = False
        pod = line.lstrip('# ').strip()
        anchor = pod_anchor(pod)
        if not pod.startswith('---'): # --- indicates end of podlings
            line = f'<a class="selflink" id="{anchor}" href="#{anchor}">{line.strip()}</a>\n'
            links[anchor] = "-- " + pod
            return current_s, line

    # Start of a podling section?
    if line.strip() == '--------------------' and 'Incubator Project' in info['sname']:
        info['podhdr'] = True

    # anything else
    return current_s, line

HDR="""<html>
<head>
<meta charset="UTF-8">
<style>
.selflink {text-decoration: none}
</style>
</head>
<body>
<a href="#index">Index</a>
"""

FTR="""</body>
</html>
"""

def text2html(inp, out, extrahdr=''):
    """html-ise text"""
    links = {}
    info = {}
    # init entries
    info['sname'] = ''
    info['podhdr'] = False
    out.write(HDR)
    out.write(extrahdr)
    out.write('<pre>')
    cur_s = None
    for line in inp:
        line = escape(line, quote=False) # probably don't need to escape quotes
        cur_s, line = add_anchor(cur_s, line, links, info)
        out.write(line)
    out.write('</pre>\n')
    out.write('<h2 id="index">Index</h2>\n')
    out.write('<ul>\n')
    level = 1
    for link, text in links.items():
        if re.search(r'\d[A-Z]{1,2}$', link): # second level link
            if level == 1:
                out.write('<ul>\n')
                level = 2
        else:
            if level == 2:
                out.write('</ul>\n')
                level = 1
        out.write(f'<li><a href="#{link}">{text}</a></li>\n')
    if level == 2:
        out.write('</ul>\n')
        level = 1
    out.write('</ul>\n')
    out.write(FTR)

def process_files(infile, outfile):
    with open(infile, 'r', encoding='utf8') as inp:
        with open(outfile, 'w', encoding='utf8') as out:
            text2html(inp,out)

def main():
    """Main"""
    infile = sys.argv[1]
    outfile = sys.argv[2]
    process_files(infile, outfile)

if __name__ == '__main__':
    main()
