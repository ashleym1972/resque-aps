# require 'resque/tasks'
# will give you the resque tasks

namespace :resque do
  task :setup

  desc "Queue an APN in Resque"
  task :aps => :setup do
    require 'resque'
    require 'resque_aps'

  end

end