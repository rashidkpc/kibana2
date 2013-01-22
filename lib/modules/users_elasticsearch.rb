require 'lib/modules/elasticsearchmod'

class UsersElasticSearch
  # Required function, accepts a KibanaConfig object
  def initialize(config)
    @config = config
    @index = 'kibana'
    @utype = 'user'
    @gtype = 'group'

    puts "Initializing elasticsearch module"
    @uesm = Elasticsearchmod.new(@index,@utype)
    @gesm = Elasticsearchmod.new(@index,@gtype)

    puts "Initializing elasticsearch for kibana user management..."
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

  def users()
    u = @uesm.get_all('username')
    return u.sort
  end

  # Update the user's password
  def set_password(username,password)
    add_user(username,password)
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
    defaults = {"group" => group, "members" => "["+username+"]"}
    result = @gesm.add_term_to_record_array(group, "members", username, defaults)
  end

  def rm_user_from_group(username,group)
    result = @gesm.del_term_from_record_array(group, "members", username)
  end

  def add_group(group, members)
    members = members || []
    values = {"group" => group, "members" => members}
    result = @gesm.set_by_id(group, values)
  end

  # Required function, returns user's groups membership
  def membership(username)
    g = lookup_user_groups(username)
    return g.sort
  end

  def group_members(group)
    g = @gesm.get_by_id(group)
    if g and g['members']
      return g['members'].sort
    else
      return []
    end
  end

  # Required function, returns a list of all groups
  def groups()
    g = @gesm.get_all('group')
    return g.sort
  end

  def del_user(name)
    r = @gesm.del_by_id(name)
  end

  def del_group(name)
    r = @gesm.del_by_id(name)
  end

end

# Required function, returns the users
# class for this module.
def get_users_module(config)
  return UsersElasticSearch.new(config)
end
