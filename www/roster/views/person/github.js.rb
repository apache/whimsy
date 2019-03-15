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
              _a gh, href: "https://github.com/" + gh
            end
          end

        end
      end
    end
  end
end

