require 'whimsy/asf'
require 'yaml'

incubator_content = ASF::SVN['asf/incubator/public/trunk/content']
ASF::Podlings.list.select{ |p| p.status == 'current'}.each_entry{ |podling|
  pod_status_yml = "#{incubator_content}/podlings/#{podling.resource}.yml"
  File.open(pod_status_yml, 'w') {|f| f.write(podling.default_status.to_yaml) }
}