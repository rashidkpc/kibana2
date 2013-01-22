require 'net/ldap'

class AuthLDAP
  # Required function, accepts a KibanaConfig object
  def initialize(config)
    @ldap = Net::LDAP.new
    @ldap.host = (defined? config::Ldap_host) ? config::Ldap_host : "127.0.0.1"
    @ldap.port = (defined? config::Ldap_port) ? config::Ldap_port : 389
    @ldap_user_base = (defined? config::Ldap_user_base) ? config::Ldap_user_base : "dc=example, dc=com"
    @ldap_group_base = (defined? config::Ldap_group_base) ? config::Ldap_group_base : "dc=example, dc=com"
    @ldap_suffix = (defined? config::Ldap_domain_fqdn) ? "@" + config::Ldap_domain_fqdn : ""
  end

  # Required function, authenticates a username/password
  def authenticate(username,password)
    begin
      @ldap.auth username + @ldap_suffix, password
      if @ldap.bind
        return true
      end
    rescue
    end
    return false
  end
end

# Required function, returns the auth
# class for this module.
def get_auth_module(config)
  return AuthLDAP.new(config)
end
