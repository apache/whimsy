#!/usr/bin/env ruby
PAGETITLE = "ASF Download Page Checker - BETA"
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require "../../tools/download_check.rb"

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        'https://www.apache.org/legal/release-policy.html#release-announcements' => 'Release announcements',
        'https://www.apache.org/dev/release-distribution#download-links' => 'Download links and cryptographic files',
        'https://www.apache.org/dev/release-download-pages.html#download-page' => 'KEYS file and download verification',
        'https://www.apache.org/dev/release-distribution#sigs-and-sums' => 'MD5 and SHA1 are deprecated',
      },
      helpblock: -> {
        _p do
          _b '*** BETA ***'
        end
        _p 'N.B. Cannot check download pages that use JavaScript to generate the links'
        _p 'This page can be used to check that an Apache download page has been set up correctly.'
        _p do
          _ 'The download page is checked for the following:'
          _ul do
            _li 'Does not link to dist.apache.org'
            _li 'Page does not reference repository.apache.org'
            _li 'Has link to KEYS file'
            _li 'It must refer to the need to verify downloads'
            _li 'If a gpg verify example is given, should include second parameter'
            _li 'Each artifact has a signature and a hash, which should not be MD5 or SHA1'
#            _li 'If a version is specified, there must be an artifact link with that version'
            _li 'There must be some artifact references on the page'
          end
          _p 'If any errors are found, no further checks are made unless "Always check links" is enabled'
          _p 'Links are checked by using HTTP HEAD requests; however links to the archive server are not checked unless "Check archive server links" is selected'
        end
      }
    ) do
      _whimsy_panel('Check Download page', style: 'panel-success') do
        _form.form_horizontal method: 'post' do
          _div.form_group do
            _label.control_label.col_sm_2 'Page URL', for: 'url'
            _div.col_sm_10 do
              _input.form_control.name name: 'url', required: true,
                value: ENV['QUERY_STRING'],
                placeholder: 'download URL',
                size: 50
            end
          end
          _div.form_group do
            _label.control_label.col_sm_2 'TLP override', for: 'tlp'
            _div.col_sm_10 do
              _input.form_control.name name: 'tlp', required: false,
                placeholder: 'optional TLP override',
                size: 50
            end
          end
#          _div.form_group do
#            _label.control_label.col_sm_2 'Version to check', for: 'version'
#            _div.col_sm_10 do
#              _input.form_control.name name: 'version', required: false,
#                placeholder: 'optional version to check',
#                size: 50
#            end
#          end
          _div.form_group do
            _label.control_label.col_sm_2 'Always check links', for: 'checklinks'
            _div.col_sm_10 do
              _input name: 'checklinks', type: 'checkbox', value: 'true', checked: false
            end
          end
          _div.form_group do
            _label.control_label.col_sm_2 'Never check links', for: 'nochecklinks'
            _div.col_sm_10 do
              _input name: 'nochecklinks', type: 'checkbox', value: 'true', checked: false
            end
          end
          _div.form_group do
            _label.control_label.col_sm_2 'Check links to archive server', for: 'archivecheck'
            _div.col_sm_10 do
              _input name: 'archivecheck', type: 'checkbox', value: 'true', checked: false
            end
          end
          _div.form_group do
            _div.col_sm_offset_2.col_sm_10 do
              _input.btn.btn_default type: 'submit', value: 'Check Page'
            end
          end
        end
      end
      _div.well.well_lg do
        if _.post?
          doPost(
            {
              url: @url,
              tlp: @tlp,
              version: '', # TODO @version when implemented
              checklinks: @checklinks == 'true',
              nochecklinks: @nochecklinks == 'true',
              archivecheck: @archivecheck == 'true',
            })
        end
      end
    end
  end
end

