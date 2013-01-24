require 'etc'
require 'rpam'

include Rpam

class AuthPam
  # Required function, accepts a KibanaConfig object
  def initialize(config)
  end

  # Required function, authenticates a username/password
  def authenticate(username,password)
    begin
      if authpam(username,password)
        return true
      else
        raise "User authentication failed"
      end
    rescue Exception => e
      return false
    end
  end
end

# Required function, returns the auth
# class for this module.
def get_auth_module(config)
  return AuthPam.new(config)
end
