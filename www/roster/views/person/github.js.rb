#
# Render and edit a person's GitHub user name
#

class PersonGitHub < React
  def render
    committer = @@person.state.committer

    _tr do
      _td 'GitHub username'
      _td do
        _a committer.githubUsername, 
          href: "https://github.com/" + committer.githubUsername
      end
    end
  end
end

