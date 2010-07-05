load 'tasks/resque_aps.rake'

$LOAD_PATH.unshift 'lib'

task :default => :test

desc "Run tests"
task :test do
  Dir['test/*_test.rb'].each do |f|
    require f
  end
end


desc "Build a gem"
task :gem => [ :test, :gemspec, :build ]

begin
  begin
    require 'jeweler'
  rescue LoadError
    puts "Jeweler not available. Install it with: "
    puts "gem install jeweler"
  end

  require 'resque_aps/version'

  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "resque-aps"
    gemspec.summary = "Queuing system for Apple's Push Service on top of Resque"
    gemspec.description = %{Queuing system for Apple's Push Service on top of Resque.
  Adds methods enqueue_aps to queue a notification message.
  Also includes helper classes and methods to format JSON.}
    gemspec.email = "ashleym1972@gmail.com"
    gemspec.homepage = "http://github.com/ashleym1972/resque-aps"
    gemspec.authors = ["Ashley Martens"]
    gemspec.version = ResqueAps::Version

    gemspec.add_dependency "redis", ">= 2.0.1"
    gemspec.add_dependency "resque", ">= 1.8.0"
    gemspec.add_development_dependency "jeweler"
    gemspec.add_development_dependency "mocha"
    gemspec.add_development_dependency "rack-test"
  end
end


desc "Push a new version to Gemcutter"
task :publish => [ :test, :gemspec, :build ] do
  system "git tag v#{ResqueAps::Version}"
  system "git push origin v#{ResqueAps::Version}"
  system "git push origin master"
  system "gem push pkg/resque-aps-#{ResqueAps::Version}.gem"
  system "git clean -fd"
end
