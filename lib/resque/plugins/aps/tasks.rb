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

    desc "Reset the queued worker counts"
    task :reset_queue_workers => :setup do
      require 'resque'
      require 'resque_aps'

      application_names = Resque.aps_application_names(0, 0)
      application_names.each do |application_name|
        Resque.redis.set(Resque.aps_application_queued_key(application_name), 0)
      end      
    end
  end

end