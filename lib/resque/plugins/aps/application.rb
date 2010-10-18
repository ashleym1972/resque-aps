require 'openssl'

module Resque
  module Plugins
    module Aps
      class Application
        include Resque::Plugins::Aps::Helper
        extend Resque::Plugins::Aps::Helper

        attr_accessor :name, :cert_file, :cert_passwd

        @queue = "apple_push_service"

        def inspect
          "#<#{self.class.name} #{name.inspect}, #{cert_passwd.inspect}, #{cert_file.inspect}>"
        end
    
        def self.perform(*args)
          count = 0
          start = Time.now
          app_name = args[0]
          Resque.aps_application(app_name).socket do |socket, app|
            while true
              n = Resque.dequeue_aps(app_name)
              if n.nil?
                if app.aps_nil_notification_retry? count, start
                  next
                else
                  break
                end
              end

              app.before_aps_write n
              begin
                n.batch_id = count + 1
                n.expiry   = Time.now.utc.to_i + 3600
                socket.write(n.formatted)
                app.after_aps_write n
                count += 1
                # resp = socket.read
                # if resp && resp != ""
                #   # logger.error "Failure response: #{resp.inspect}" if logger
                #   logger.error "Failure response: #{resp.bytes.to_a.map{|i| i.to_s(16)}.join}" if logger
                #   break
                # end
              rescue
                logger.error Application.application_exception($!, app_name) if logger
                app.failed_aps_write n, $!
                logger.error "#{$!}: Sent #{count} notifications before failure." if logger
                Resque.enqueue_aps(app_name, n)
                break
              end
            end
          end
          logger.info("Sent #{count} #{app_name} notifications in batch over #{Time.now - start} sec.") if logger
        ensure
          Resque.dequeue_aps_application(app_name)
        end
    
        #
        # Create the TCP and SSL sockets for sending the notification
        #
        def self.create_sockets(cert, passphrase, host, port)
          ctx = OpenSSL::SSL::SSLContext.new
          ctx.key = OpenSSL::PKey::RSA.new(cert, passphrase)
          ctx.cert = OpenSSL::X509::Certificate.new(cert)

          s = TCPSocket.new(host, port)
          ssl = OpenSSL::SSL::SSLSocket.new(s, ctx)
          ssl.sync = true

          return s, ssl
        end

        #
        # Close the sockets
        #
        def self.close_sockets(socket, ssl_socket)
          begin
            if ssl_socket
              ssl_socket.close
            end
          rescue
            Resque.logger.error("#{$!}: #{$!.backtrace.join("\n")}") if Resque.logger
          end

          begin
            if socket
              socket.close
            end
          rescue
            Resque.logger.error("#{$!}: #{$!.backtrace.join("\n")}") if Resque.logger
          end
        end

        def self.application_exception(exception, name)
          exc = Exception.new("#{exception} (#{name})")
          exc.set_backtrace(exception.backtrace)
          return exc
        end
    
        def initialize(attributes)
          attributes.each do |k, v|
            respond_to?(:"#{k}=") ? send(:"#{k}=", v) : raise(Resque::Plugins::Aps::UnknownAttributeError, "unknown attribute: #{k}")
          end
        end
    
        def socket(cert = nil, certp = nil, host = nil, port = nil, &block)
          logger.debug("resque-aps: ssl_socket(#{name})") if logger
          exc = nil

          begin
            socket, ssl_socket = Application.create_sockets(cert || File.read(cert_file),
                                                            certp || cert_passwd,
                                                            host || Resque.aps_gateway_host,
                                                            port || Resque.aps_gateway_port)
          rescue
            raise Application.application_exception($!, name)
          end
      
          begin
            ssl_socket.connect
            yield ssl_socket, self if block_given?
          rescue
            exc = Application.application_exception($!, name)
            if $!.message =~ /^SSL_connect .* certificate (expired|revoked)/
              notify_aps_admin exc
            end
            raise exc
          ensure
            Application.close_sockets(socket, ssl_socket)
          end

          exc
        end

        def to_hash
          {'name' => name, 'cert_file' => cert_file, 'cert_passwd' => cert_passwd}
        end
    
        def to_json
          to_hash.to_json
        end

        def before_aps_write(notification)
          logger.debug("ResqueAps[before_write]: #{notification}") if logger
        end

        def after_aps_write(notification)
          logger.debug("ResqueAps[after_write]: #{notification}") if logger
        end

        def failed_aps_write(notification, exception)
          logger.error("ResqueAps[write_failed]: #{exception} (#{notification}): #{exception.backtrace.join("\n")}") if logger
        end

        def notify_aps_admin(exception)
        end

        def aps_nil_notification_retry?(sent_count, start_time)
          false
        end

        def before_aps_read
          logger.debug("ResqueAps[before_read]:") if logger
        end
    
        def after_aps_read(feedback)
          logger.debug("ResqueAps[after_read]: #{feedback.to_s}") if logger
        end
    
        def aps_read_error(exception)
          logger.error("ResqueAps[read_error]: #{exception} (#{name}): #{exception.backtrace.join("\n")}") if logger
        end

        def aps_read_failed
          logger.error("ResqueAps[read_failed]: Bad data on the socket (#{name})") if logger
        end





        def queued_count
          (redis.get(Resque.aps_application_queued_key(name)) || 0).to_i
        end

        def lock_key
          @lock_key ||= "#{Resque.aps_application_key(name)}:lock"
        end
        
        def redis
          Resque.redis
        end
        
        def acquire_lock
          if redis.setnx(lock_key, Time.now.utc.to_i + 1)
            true
          elsif Time.at(redis.get(lock_key).to_i) > Time.now
            delete_lock
            acquire_lock
          else
            false
          end
        end

        def delete_lock
          redis.del(lock_key)
        end

        def enqueue(override = false)
          count_apps = 0
          count_not  = 0
          locked     = false

          unless override
            count_apps = queued_count
            if count_apps == 0
              locked     = acquire_lock
              return unless locked
              count_apps = queued_count
            end
            count_not  = Resque.aps_notification_count_for_application(name)
          end

          if count_apps <= 0 || (count_apps < Resque.aps_application_job_limit && (count_not > Resque.aps_queue_size_upper && count_not % (Resque.aps_queue_size_upper / 10) == 0))
            enqueue(Resque::Plugins::Aps::Application, name)
            redis.incr(Resque.aps_application_queued_key(name))
            delete_lock if locked
          end
        end

        def dequeue
          redis.decr(Resque.aps_application_queued_key(name))
        end

      end
    end
  end
end