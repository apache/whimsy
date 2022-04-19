#
# Display the list of parts for a given message
#

_html do
  _link rel: 'stylesheet', type: 'text/css',
    href: "../../secmail.css?#{@cssmtime}"

  _header_ do
    _h3.bg_success do
      _a 'ASF Secretary Mail', href: '../..', target: '_parent'
    end
  end

  _ul_ do
    _li! {_a 'text', href: '_body_', target: 'content'}
    _li! {_a 'headers', href: '_headers_', target: 'content'}
    _li! {_a 'raw', href: '_raw_', target: 'content'}
    _li! {_a 'reparse', href: '_reparse_', target: 'content'}
  end

  _div_.parts!

  _hr_

  _h4_ 'Links'
  _ul do
    _li do
      _a 'Response time', target: 'content',
        href: '/secretary/response-time'
    end
    _li do
      _a 'Mail Search', target: 'content',
        href: 'https://lists.apache.org/list.html?board@apache.org'
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
        href: ASF::SVN.svnurl('iclas')
    end
    _li do
      _a 'CCLAs', target: 'content',
        href: ASF::SVN.svnurl('cclas')
    end
    _li do
      _a 'Grants', target: 'content',
        href: ASF::SVN.svnurl('grants')
    end
    _li do
      _a 'Incubator', target: 'content',
        href: 'https://incubator.apache.org'
    end
    _li do
      _a 'Project Proposals', target: 'content',
        href: 'https://cwiki.apache.org/confluence/display/incubator/ProjectProposals'
    end
    _li do
      _a 'ICLA lint', target: 'content',
        href: '/secretary/icla-lint'
    end
    _li do
      _a 'Public names', target: 'content',
        href: '/secretary/public-names'
    end
    _li do
      _a 'Board subscriptions', target: 'content',
        href: '/board/subscriptions/'
    end
    _li do
      _a 'Mail aliases', target: 'content',
        href: 'https://id.apache.org/info/MailAlias.txt'
    end
    _li do
      _a 'Member list (members.txt)', target: 'content',
        href: ASF::SVN.svnpath!('foundation', 'members.txt')
    end
    _li do
      _a 'Foundation commits', target: 'content',
        href: 'https://lists.apache.org/list?foundation-commits@apache.org'
    end
    _li do
      _a 'How to use this tool', href: '../../HOWTO.html',
        target: 'content'
    end
    if File.exist? '/var/tools/secretary/secmail'
      _li {_p {_hr}}
      _li {_a 'Upload email', href: 'upload', target: 'content'}
    end
  end

  _script src: "../../app.js?#{@appmtime}"
  _.render '#parts', timeout: 1 do
    _Parts attachments: @attachments, headers: @headers, projects: @projects,
      meeting: @meeting
  end

end
