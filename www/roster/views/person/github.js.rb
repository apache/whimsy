#
# Render and edit a person's GitHub user name
#

class PersonGitHub < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'github' do
      _div.name 'GitHub username'

      _div.value do

        if @@edit == :github

          _form method: 'post' do
            _input name: 'githubuser', value: committer.githubUsername
            _input type: 'submit', value: 'submit'
          end

        else

          _ul committer.githubUsername do |gh|
            _li do
              _a gh, href: "https://github.com/" + gh +"/" # / catches trailing spaces
              unless gh =~ /^[-0-9a-zA-Z]+$/ # should agree with the validation in github.json.rb
                _ ' '
                _span.bg_warning "Invalid: '#{gh}' expecting only alphanumeric and '-'"
              end
            end
          end

        end
      end
    end
  end
end

