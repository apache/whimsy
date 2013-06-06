#
# Update packaging information if the previous info is over a day old
# Install update-notifier-common to keep the update-success-stamp current
#

execute "apt-get-update-periodic" do
  timestamp = '/var/lib/apt/periodic/update-success-stamp'
  command "apt-get update && touch #{timestamp}"
  ignore_failure true
  only_if do
    not File.exists?(timestamp) or File.mtime(timestamp) < Time.now - 86400
  end
end

package 'update-notifier-common'
