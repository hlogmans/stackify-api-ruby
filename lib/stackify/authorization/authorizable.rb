module Stackify::Authorizable
  autoload :AuthorizationClient,  'stackify/authorization/authorization_client'

  def self.included(klass)
    klass.extend ClassMethods
  end

  module ClassMethods
    @@authorized = false
    @@auth_lock = Mutex.new
    @@auth_client = nil

    def authorize attempts=3
      @@auth_lock.synchronize do
        return unless @@auth_client.nil?
        @@auth_client = Stackify::Authorizable::AuthorizationClient.new
        @@auth_client.auth attempts
      end
    end

    def authorized?
      @@auth_lock.synchronize do
        @@authorized
      end
    end

    def authorized!
      Stackify.internal_log :info, 'Setting authorized...'
      @@auth_lock.synchronize do
        @@authorized = true
      end
      Stackify.internal_log :info, 'Authorized set...'
      Stackify.internal_log :info, "Authorized? : #{authorized?}"
      
    end

    def successfull_authorisation response
      Stackify::EnvDetails.instance.update_auth_info JSON.parse(response.body)
      Stackify.internal_log :info, 'Authorization is finished successfully.'
    end

    def unsuccessfull_authorisation response, caller
      Stackify.log_internal_error "Authorization finally failed: #{response_string(response)}"
      Stackify.shutdown_all caller unless @@authorized
    end

    def if_not_authorized failure_msg, &block
      failure_msg += ', but Stackify module is not authorized'
      if Stackify.authorized?
        begin
          block.call
        rescue => e
          Stackify.log_internal_error e.message
        end
      else
        Stackify.log_internal_error failure_msg
      end
    end

    def response_string r
      return '' if r.nil?
      "Status: #{r.try(:status)}, Message: '#{r.try(:body)}'"
    end

  end

end
