module Resque
  module Plugins
    module Aps
  class Notification
    include Resque::Plugins::Aps::Helper
    extend Resque::Plugins::Aps::Helper

    attr_accessor :application_name, :device_token, :payload

    def initialize(attributes)
      attributes.each do |k, v|
        respond_to?(:"#{k}=") ? send(:"#{k}=", v) : raise(Resque::Plugins::Aps::UnknownAttributeError, "unknown attribute: #{k}")
      end
    end
        
    def inspect
      "#<#{self.class.name} #{application_name.inspect}, #{device_token.inspect}, #{payload.inspect}>"
    end
    
    def to_s
      "#{device_token.inspect}, #{payload.inspect}"
    end
    
    def to_hash
      {:application_name => application_name, :device_token => device_token, :payload => payload}
    end

    # SSL Configuration
    #   open Keychain Access, and export the "Apple Development Push" certificate associated with your app in p12 format
    #   Convert the certificate to PEM using openssl:
    #      openssl pkcs12 -in mycert.p12 -out client-cert.pem -nodes -clcerts

    # To use with cross application push
    # Notification.new(:user => user, :current_product => product, :cross_app => { :capabilities => 'cross_app', :payload => '{aps.....}' })

    #
    # https://developer.apple.com/iphone/prerelease/library/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/ApplePushService/ApplePushService.html#//apple_ref/doc/uid/TP40008194-CH100-SW1
    #
    # Table 2-1  Keys and values of the aps dictionary
    # alert |  string or dictionary
    # => If this property is included, iPhone OS displays a standard alert. You may specify a string as the value of alert or a dictionary as its value.
    # => If you specify a string, it becomes the message text of an alert with two buttons: Close and View. If the user taps View, the application is launched.
    # => Alternatively, you can specify a dictionary as the value of alert. See Table 2-2 for descriptions of the keys of this dictionary.
    #
    # badge |  number
    # => The number to display as the badge of the application icon. If this property is absent, any badge number currently shown is removed.
    #
    # sound |  string
    # => The name of a sound file in the application bundle. The sound in this file is played as an alert.
    # => If the sound file doesn’t exist or default is specified as the value, the default alert sound is played.
    # => The audio must be in one of the audio data formats that are compatible with system sounds; see “Preparing Custom Alert Sounds” for details.
    #
    # Table 2-2  Child properties of the alert property
    # body |  string
    # => The text of the alert message.
    #
    # action-loc-key |  string or null
    # => If a string is specified, displays an alert with two buttons, whose behavior is described in Table 2-1.
    # => However, iPhone OS uses the string as a key to get a localized string in the current localization to use for the right button’s title instead of “View”. 
    # => If the value is null, the system displays an alert with a single OK button that simply dismisses the alert when tapped. 
    #
    # loc-key |  string
    # => A key to an alert-message string in a Localizable.strings file for the current localization (which is set by the user’s language preference). 
    # => The key string can be formatted with %@ and %n$@ specifiers to take the variables specified in loc-args. See “Localized Formatted Strings” for more information.
    #
    # loc-args |  array of strings
    # => Variable string values to appear in place of the format specifiers in loc-key. See “Localized Formatted Strings” for more information.
    #
    #
    # Example Result:
    # {
    #    "aps" : {
    #        "alert" : "You got your emails.",
    #        "badge" : 9,
    #        "sound" : "bingbong.aiff"
    #    },
    #    "acme1" : "bar",
    #    "acme2" : 42
    #}
    # Or
    # {
    #    "aps" : {
    #        "alert" : {
    #            "action-loc-key" : "PLAY",
    #            "loc-key" : "SERVER.ERROR"
    #            "loc-args" : ["bob", "sierra"]
    #        },
    #        "badge" : 9,
    #        "sound" : "bingbong.aiff"
    #    },
    #    "acme1" : "bar",
    #    "acme2" : 42
    #}
    def self.to_payload(alert = nil, badge = nil, sound = nil, app_data = nil)
      result = ActiveSupport::OrderedHash.new
      result['aps'] = ActiveSupport::OrderedHash.new
      result['aps']['alert'] = self.format_alert(alert) unless alert.blank?
      result['aps']['badge'] = badge.to_i unless badge.blank?
      result['aps']['sound'] = sound unless sound.blank?
      result.merge!(app_data) unless app_data.blank?
      self.to_json(result)
    end

    #
    # Create an ordered hash of the data in the given alert hash
    #
    def self.format_alert(alert)
      if alert.is_a? Hash
        result = ActiveSupport::OrderedHash.new
        result['action-loc-key'] = alert['action-loc-key'] unless alert['action-loc-key'].blank?
        result['loc-key']        = alert['loc-key']        unless alert['loc-key'].blank?
        unless alert['loc-args'].blank?
          if alert['loc-args'].is_a? Hash
            result['loc-args']     = Array.new(alert['loc-args'].size)
            alert['loc-args'].map do |key,value|
              result['loc-args'][key.to_i] = value
            end
          else
            result['loc-args'] = alert['loc-args']
          end
        end
        return result
      else
        return alert
      end
    end

    #
    # Generate a JSON string from the given Hash/Array which does not screw up the ordering of the Hash
    #
    def self.to_json(hash)
      if hash.is_a? Hash
        hash_keys = hash.keys

        result = '{'
        result << hash_keys.map do |key|
          if hash[key].is_a?(Hash) || hash[key].is_a?(Array)
            "#{key.to_s.to_json}:#{to_json(hash[key])}"
          else
            "#{key.to_s.to_json}:#{hash[key].to_json}"
          end
        end * ','
        result << '}'
      elsif hash.is_a? Array
        result = '['
        result << hash.map do |value|
          if value.is_a?(Hash) || value.is_a?(Array)
            "#{to_json(value)}"
          else
            value.to_json
          end
        end * ','
        result << ']'
      end
    end
    
    #
    # The message formatted for sending in binary
    #
    def formatted
      Resque::Plugins::Aps::Notification.format_message_for_sending(self.device_token, self.payload)
    end

    #
    # A HEX dump of the formatted message so that you can debug the binary data
    #
    def to_hex
      formatted.unpack('H*')
    end

    #
    # HEX version of the device token
    #
    def self.device_token_hex(device_token)
      #self.device_token
      [device_token.gsub(' ', '')].pack('H*')
    end

    #
    # Combine the device token and JSON into a binary package to send.
    #
  	def self.format_message_for_sending(device_token, json)
  	  token_hex = self.device_token_hex(device_token)
      tl = [token_hex.length].pack('n')
      # puts("token length [#{tl.unpack('H*')}]")
      # puts("device token [#{token_hex.unpack('H*')}]")
      # logger.debug "Formatting #{json} for #{self.device_token}"
      jl = [json.length].pack('n')
      # puts("json length  [#{jl.unpack('H*')}]")
      # puts("json         [#{json}]")
      "\0#{tl}#{token_hex}#{jl}#{json}"
      # "\0\0 #{token_hex}\0#{json.length.chr}#{json}"
  	end
  end
  end
end
end