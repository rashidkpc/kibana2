require 'lib/modules/elasticsearchmod'

class AuthElasticSearch
  # Required function, accepts a KibanaConfig object
  def initialize(config)
    @config = config
    @index = 'kibana'
    @utype = 'user'
    @gtype = 'group'

    puts "Initializing elasticsearch module"
    @uesm = Elasticsearchmod.new(@index,@utype)
    @gesm = Elasticsearchmod.new(@index,@gtype)

    puts "Initializing elasticsearch for kibana auth..."
    # Make sure the default admin user is present
    p = @@users_module.lookup_user(config::Auth_Admin_User)
    if (p == nil)
      puts "Adding default admin user #{config::Auth_Admin_User} ..."
      add_user(config::Auth_Admin_User,config::Auth_Admin_Pass)
    end
  end

  # Required function, authenticates a username/password
  def authenticate(username,password)
    user = @@users_module.lookup_user(username)
    return false if not user
    salt=user['salt']
    hashpass=Digest::SHA256.hexdigest(salt + password)
    if(hashpass == user['password'])
      return true
    end
    return false
  end
end

# Required function, returns the auth
# class for this module.
def get_auth_module(config)
  return AuthElasticSearch.new(config)
end
