# See http://unicorn.bogomips.org/Unicorn/Configurator.html for complete
# documentation.

app = {
  :workers =>  ENV['UNICORN_WORKERS'] || 2,
  :app_home => ENV['UNICORN_HOME']    || File.expand_path(File.dirname(__FILE__) + "/.."),
  :timeout =>  ENV["UNICORN_TIMEOUT"] || 90
}

# how many worker processes to start
worker_processes app[:workers].to_i

# listen on a Unix domain socket
listen "#{app[:app_home]}/tmp/web.sock", :backlog => 64

# nuke workers that don't respond after X seconds
timeout app[:timeout].to_i

preload_app true

GC.respond_to?(:copy_on_write_friendly=) and
    GC.copy_on_write_friendly = true

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
