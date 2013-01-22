require 'net/ldap'

class UsersLDAP
  # Required function, accepts a KibanaConfig object
  def initialize(config)
    @ldap = Net::LDAP.new
    @ldap.host = (defined? config::Ldap_host) ? config::Ldap_host : "127.0.0.1"
    @ldap.port = (defined? config::Ldap_port) ? config::Ldap_port : 389
    @ldap_user_base = (defined? config::Ldap_user_base) ? config::Ldap_user_base : "dc=example, dc=com"
    @ldap_group_base = (defined? config::Ldap_group_base) ? config::Ldap_group_base : "dc=example, dc=com"
    @ldap_suffix = (defined? config::Ldap_domain_fqdn) ? "@" + config::Ldap_domain_fqdn : ""
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

  def del_user(name)
    return
  end

  def del_group(name)
    return
  end
end

# Required function, returns the auth
# class for this module.
def get_users_module(config)
  return UsersLDAP.new(config)
end
