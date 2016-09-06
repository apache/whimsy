#
# Display the list of parts for a given message
#

_html do
  _link rel: 'stylesheet', type: 'text/css', 
    href: "../../secmail.css?#{@cssmtime}"

  _header_ do
    _h1.bg_success do
      _a 'Secretary Mail', href: '../..', target: '_parent'
    end
  end

  _ul_ do
    _li! {_a 'text', href: '_body_', target: 'content'}
    _li! {_a 'headers', href: '_headers_', target: 'content'}
    _li! {_a 'raw', href: '_raw_', target: 'content'}
  end

  _div.parts!

  _script src: '../../app.js'
  _.render '#parts' do
    _Parts attachments: @attachments, headers: @headers
  end

  _hr_

  _h4_ 'Links'
  _ul do
    _li do
      _a 'Response time', target: 'content',
        href: 'https://whimsy.apache.org/secretary/response-time'
    end
    _li do
      _a 'Mail Search', target: 'content',
        href: 'https://mail-search.apache.org/search'
    end
    _li do
      _a 'Mail Browse', target: 'content',
        href: 'https://mail-search.apache.org/members/private-arch/'
    end
    _li do
      _a 'Committers by id', target: 'content',
        href: 'http://people.apache.org/committer-index.html'
    end
    _li do
      _a 'ICLAs', target: 'content',
        href: 'https://svn.apache.org/repos/private/documents/iclas'
    end
    _li do
      _a 'CCLAs', target: 'content',
        href: 'https://svn.apache.org/repos/private/documents/cclas'
    end
    _li do
      _a 'Grants', target: 'content',
        href: 'https://svn.apache.org/repos/private/documents/grants'
    end
    _li do
      _a 'Incubator', target: 'content',
        href: 'http://incubator.apache.org'
    end
    _li do
      _a 'Project Proposals', target: 'content',
        href: 'https://wiki.apache.org/incubator/ProjectProposals'
    end
    _li do
      _a 'ICLA lint', target: 'content',
        href: 'https://whimsy.apache.org/secretary/icla-lint'
    end
    _li do
      _a 'Public names', target: 'content',
        href: 'https://whimsy.apache.org/secretary/public-names'
    end
    _li do
      _a 'Board subscriptions', target: 'content',
        href: 'https://whimsy.apache.org/board/subscriptions/'
    end
    _li do
      _a 'Mail aliases', target: 'content',
        href: 'https://id.apache.org/info/MailAlias.txt'
    end
    _li do
      _a 'Member list', target: 'content',
        href: 'https://svn.apache.org/repos/private/foundation/members.txt'
    end
    _li do
      _a 'How to use this tool', href: 'HOWTO.html',
        target: 'content'
    end
    if File.exist? '/var/tools/secretary/secmail'
      _li {_p {_hr}}
      _li {_a 'Upload email', href: 'upload', target: 'content'}
    end
  end
end
