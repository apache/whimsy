#
# Render and edit a person's GitHub user name
#

class PersonGitHub < Vue
  def render
    committer = @@person.state.committer

    _div.row do
      _div.name do
        _ 'ASF-linked GitHub username'
      end
      _div.value do
        if committer.asf_githubStringID.empty?
          _ '(not defined)'
          _br
          _a 'Link a GitHub username to your ASF id', href: 'https://gitbox.apache.org/boxer/'
        else
          _a committer.asf_githubStringID, href: "https://github.com/#{committer.asf_githubStringID}"
        end
      end
    end

    _div.row data_edit: 'github' do
      _div.name do
        _ 'User-provided GitHub username(s)'
      end

      _div.value do

        if @@edit == :github

          _form method: 'post' do
            current = 1
            prefix = 'githubuser'
            _input type: 'hidden', name: 'array_prefix', value: prefix

            _div committer.githubUsername do |name|
              _input style: 'font-family:Monospace', size: 20, name: prefix + current, value: name
              _br
              current += 1
            end
            # Spare field to allow new entry to be added
            _input style: 'font-family:Monospace', size: 20, name: prefix + current, placeholder: '<new GitHub name>'
            _br

            _input type: 'submit', value: 'submit'
          end

        else
          if committer.githubUsername.empty?
            _ul do
              _li '(none defined)'
            end
          else
            _ul committer.githubUsername do |gh|
              _li do
                _a gh, href: 'https://github.com/' + gh +'/' # / catches trailing spaces
                unless gh =~ /^[-0-9a-zA-Z]+$/ # should agree with the validation in github.json.rb
                  _ ' '
                  _span.bg_warning "Invalid: '#{gh}' expecting only alphanumeric and '-'"
                end
              end
            end
            _ '(The above are added by the user, so might not match the one linked to the ASF id)'
          end
        end
      end
    end
  end
end

