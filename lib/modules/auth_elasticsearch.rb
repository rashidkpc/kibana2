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
    p = lookup_user(config::Auth_Admin_User)
    if (p == nil)
      puts "Adding default admin user #{config::Auth_Admin_User} ..."
      add_user(config::Auth_Admin_User,config::Auth_Admin_Pass)
    end
    
  end

  def lookup_user_groups(username)
    g = @gesm.get_record_ids_with_term("members", username)
    return g
  end

  def lookup_user(username)
    p = @uesm.get_by_id(username)
    return p
  end

  # Required function, authenticates a username/password
  def authenticate(username,password)
    user = lookup_user(username)
    salt=user['salt']
    hashpass=Digest::SHA256.hexdigest(salt + password)
    if(hashpass == user['password'])
      return true
    end
    return false
  end

  def add_user(username,password)
    salt = rand(65536)
    salt = salt.to_s(16)
    hashpass = Digest::SHA256.hexdigest(salt + password)
    values = {"username" => username, "password" => hashpass, "salt" => salt}
    result = @uesm.set_by_id(username, values)
  end

  # This update a groups list of users
  def add_user_2group(username,group)
    defaults = {"group" => group, "members" => [username], "tags" => []}
    result = @gesm.add_term_to_record_array(group, "members", username, defaults)
  end

  def rm_user_from_group(username,group)
    result = del_term_from_record_array(group, "members", username)
  end

  def add_group(group)
    result = @gesm.set_by_id(group, values)
  end

  # Required function, returns user's groups membership
  def membership(username)
    g = lookup_user_groups(username)
    return g.sort
  end

  # Required function, returns a list of all groups
  def groups()
    g = @gesm.get_all()
    return g.sort
  end
end

# Required function, returns the auth
# class for this module.
def get_auth_module(config)
  return AuthElasticSearch.new(config)
end
