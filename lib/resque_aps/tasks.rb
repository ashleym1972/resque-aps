# require 'resque/tasks'
# will give you the resque tasks

namespace :resque do
  task :setup

  namespace :aps do
    desc "Retrieve the current queue lengths"
    task :queue_lengths => :setup do
      require 'resque'
      require 'resque_aps'

      if Resque.aps_applications_count > 0
        puts "## START ##"
        Resque.aps_application_names(0,0).each do |app|
          puts "#{app}:#{Resque.aps_notification_count_for_application(app)}"
        end
      else
        abort "None"
      end
    end
  end

end