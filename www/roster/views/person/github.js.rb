#
# Render and edit a person's GitHub user name
#

class PersonGitHub < React
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'github' do
      _div.name 'GitHub username'

      _div.value do

        if @@person.state.edit_github

          _form method: 'post' do
            _input name: 'githubuser', defaultValue: committer.githubUsername
            _input type: 'submit', value: 'submit'
          end

        else

          _a committer.githubUsername, 
            href: "https://github.com/" + committer.githubUsername
        end

      end
    end
  end
end

