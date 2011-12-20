require 'net/http'
require 'uri'

module Resque::Plugins::Aps
  class C2dmSocket

    attr_reader :app_key, :auth_token, :uri

    def initialize(app_key, auth_token, uri = 'https://android.apis.google.com/c2dm/send')
      @app_key    = app_key
      @auth_token = auth_token
      @uri        = uri
      # product         = Product.find_by_app_key(app_key)
      # auth_token      = product.client_login_auth_token
    end

    def connect
    end

    def close
    end

    def read
    end

    def url
      url  = URI.parse(uri)
    rescue
      raise $!, "c2dm error - #{$!.message} #{uri.inspect}", $!.backtrace
    end

    def write(notification)
      registration_id = notification.device_token
      payload         = notification.payload

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')

      # TODO: Google has an invalid certificate for the web server, verify it once it is fixed
      if false && http.use_ssl? && File.directory?(ROOT_CA)
        http.ca_path      = ROOT_CA
        http.verify_mode  = OpenSSL::SSL::VERIFY_PEER
        http.verify_depth = 5
      else
        http.verify_mode  = OpenSSL::SSL::VERIFY_NONE
      end

      req = Net::HTTP::Post.new(url.path)
      req['Authorization'] = "GoogleLogin auth=#{auth_token}"

      form_hash = {
        'registration_id' => registration_id,
        'collapse_key'    => app_key
        # ,'delay_while_idle' => ''
      }
      case payload
      when String
        form_hash['data.payload'] = payload
      when Hash
        payload.each { |key, value| form_hash["data.#{key}"] = value }
      end
      req.set_form_data(form_hash)

      application  = Resque::Plugins::Aps::Application.new(:name => app_key)

      res = http.request(req)
      # This raises an error for non-2xx responses
      case res
      when Net::HTTPUnauthorized
        application.failed_aps_write(notification, Exception.new("c2dm error - The ClientLogin AUTH_TOKEN [#{req['Authorization']}] used to validate #{app_key} is invalid."))
        raise Exception.new("c2dm error - The ClientLogin AUTH_TOKEN used to validate #{app_key} is invalid.")
      when Net::HTTPServerError
        res.error!
      when Net::HTTPClientError
        ex = Exception.new("c2dm error - #{res.message.dump} (#{app_key})")
        # application.failed_aps_write(notification, ex)
        raise ex
      end

      id    = res.body[/id=(.*)/,1]
      error = res.body[/Error=(.*)/,1]

      if error.blank?
        application.after_aps_write(notification)
      else
        case error
        when 'QuotaExceeded'       # Too many messages sent by the sender. Retry after a while.
          raise Exception.new(error)
        when 'DeviceQuotaExceeded' # Too many messages sent by the sender to a specific device. Retry after a while.
          raise Exception.new(error)
        when 'InvalidRegistration' # Missing or bad registration_id. Sender should stop sending messages to this device.
          application.after_aps_read(Resque::Plugins::Aps::Feedback.new(:application_name => app_key, :device_token => registration_id))
        when 'NotRegistered'       # The registration_id is no longer valid, for example user has uninstalled the application or turned off notifications. Sender should stop sending messages to this device.
          application.after_aps_read(Resque::Plugins::Aps::Feedback.new(:application_name => app_key, :device_token => registration_id))
        when 'MessageTooBig'       # The payload of the message is too big, see the http://code.google.com/android/c2dm/index.html#limitations. Reduce the size of the message.
          raise Exception.new("c2dm error - (#{id}) #{error} (#{app_key})")
        when 'MissingCollapseKey'  # Collapse key is required. Include collapse key in the request.
          raise Exception.new("c2dm error - (#{id}) #{error} (#{app_key})")
        else                       # Unknown
          raise Exception.new("c2dm error - (#{id}) #{error} (#{app_key})")
        end
      end
    end
  end
end