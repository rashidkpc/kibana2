require 'net/ldap'

class AuthLDAP
  # Required function, accepts a KibanaConfig object
  def initialize(config)
    @ldap = Net::LDAP.new
    @ldap.host = config::Ldap_host ? config::Ldap_host : "127.0.0.1"
    @ldap.port = config::Ldap_port ? config::Ldap_port : 389
    @ldap_user_base = config::Ldap_user_base ? config::Ldap_user_base : "dc=example, dc=com"
    @ldap_group_base = config::Ldap_group_base ? config::Ldap_group_base : "dc=example, dc=com"
  end

  # Required function, authenticates a username/password
  def authenticate(username,password)
    begin
      @ldap.auth username, password
      if @ldap.bind
        return true
      end
    rescue
    end
    return false
  end

  # Required function, returns user's groups membership
  def membership(username)
    grlist = []
    return grlist.uniq.sort
  end

  # Required function, returns a list of all groups
  def groups()
    grlist = []
    return grlist.uniq.sort
  end
end

# Required function, returns the auth
# class for this module.
def get_module(config)
  return AuthLDAP.new(config)
end
