#!/usr/bin/env python

from __future__ import print_function

from contextlib import contextmanager
import cgi
import time
import functools
import ldap
import logging
import operator
import os
import re
import subprocess
import sys
import tempfile
from xml.sax.saxutils import quoteattr

try:
    from html import escape
except ImportError:
    from cgi import escape

import cgitb
#cgitb.enable()
logging.getLogger().name = 'tlpreq'
logging.getLogger().setLevel(logging.INFO)

AGENDAS_URL = 'https://svn.apache.org/repos/private/foundation/board/'
RESULT_URL = 'https://svn.apache.org/repos/infra/infrastructure/trunk/tlpreq/input/'
BASE_DN = 'dc=apache,dc=org'
OU_PEOPLE = 'ou=people,%s' % BASE_DN

print("Content-type: text/html\r\n\r\n")

def _assert_karma():
    user = os.environ['REMOTE_USER']
    assert user == os.environ['AUTHENTICATE_UID']
    lh = ldap.initialize(ldap.get_option(ldap.OPT_URI))
    filterstr = '(member=uid=%s,%s)' % (user, OU_PEOPLE)
    groups = set(attrs['cn'][0] for dn, attrs in
                 lh.search_s(BASE_DN, ldap.SCOPE_SUBTREE, filterstr, ['cn']))
    if not groups & set(['asf-secretary', 'board', 'infrastructure-root']):
        logging.warn('Insufficient karma: availid=%s groups=%r', user, groups)
        print('tlpreq: Insufficient karma\n')
        sys.exit(1)

def _get_DATE():
    pattern = r'^board_agenda_(\d\d\d\d)_(\d\d)_(\d\d)[.]txt$'
    coerce = tuple
    sentinel = coerce(time.gmtime()[:3])
    l = subprocess.check_output(['svn', 'ls', '--', AGENDAS_URL])
    return \
      max(
        filter(sentinel.__ge__,
          map(coerce,
            map(functools.partial(map, int),
              map(operator.methodcaller('groups'),
                filter(None,
                  map(re.compile(pattern).search,
                    l.splitlines())))))))

# TODO: use functools.lru_cache if availble (py3)
_DATE = None
def _date(as_str=False):
    global _DATE
    if not _DATE:
    	_DATE = _get_DATE()
    return as_str and ('%04d_%02d_%02d' % _DATE) or _DATE

INDENT = 0
def indent():
    global INDENT
    return ' ' * INDENT

@contextmanager
def tag(_name, **attrs):
    global INDENT
    _name = escape(_name)
    s = ''.join(' %s=%s' % (escape(k), quoteattr(attrs[k])) for k in attrs)
    print(indent() + "<%s%s>" % (_name, s))
    INDENT += 2
    yield
    INDENT -= 2
    print(indent() + "</%s>" % (_name, ))

def text(*args, **kwds):
    print(indent(), end='')
    for k, v in kwds:
    	if k not in ['file', 'flush']:
    		kwds[k] = escape(v)
    print(*map(escape, args), **kwds)

class Candidate(object):
    def __init__(self, s):
        words = s.strip().split()
        self.letter = words[0][:-1]
        self.name = ' '.join(words[4:-1])
        self.item = s.strip()

def main():
    _assert_karma()
    form = cgi.FieldStorage()
    url = AGENDAS_URL + 'board_agenda_%s.txt' % _date(True)
    blurb = subprocess.check_output(['svn', 'cat', '--', url])
    candidates = filter(lambda l: 'Establish' in l, blurb.splitlines())
    candidates = map(Candidate, candidates)
    if form:
        # POST
        keys = form.keys()
        assert set(keys).issubset(c.name for c in candidates)
        t = tempfile.SpooledTemporaryFile()
        for key in sorted(keys): print(key, file=t)
        f = lambda: subprocess.check_output([
            'svnmucc',
            '--with-revprop=whimsy:author=%s' % os.getenv('REMOTE_USER'),
            '-m', 'tlpreq: record %s approved TLP resolutions' % _date(True),
            '-U', RESULT_URL,
            'put', '/dev/stdin', 'victims-%s.0.txt' % _date(True),
        ], stdin=t)
        try:
            text(f())
        except subprocess.CalledProcessError as cpe:
            logging.error("svnmucc error (%d): %r", cpe.returncode, cpe.output)
            text("Commit error; logged; ask %s for help" % os.getenv('SERVER_ADMIN'))
    else:
        # GET
        with tag('form', style='margin: 0 20%'):
            for c in candidates:
                with tag('input', type='checkbox', name=c.name,
                                  checked='checked'): pass
                with tag('label'): text(c.item)
                with tag('br'): pass
            with tag('input', type='submit', value='Submit'): pass

if __name__ == '__main__':
    main()
