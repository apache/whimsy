require 'whimsy/asf'
require 'yaml'

incubator_podlings = ASF::SVN['incubator-podlings']
ASF::Podlings.list.select{ |p| p.status == 'current'}.each_entry{ |podling|
  pod_status_yml = File.join(incubator_podlings, "#{podling.resource}.yml")
  File.open(pod_status_yml, 'w') {|f| f.write(podling.default_status.to_yaml) }
}