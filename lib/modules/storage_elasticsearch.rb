require 'lib/modules/elasticsearchmod'

# class for storing permissions
class Permissions
  %w(username enabled is_admin tags).each do |meth|
    define_method(meth) { @data[meth.to_sym] }
  end

  define_method(:[]) { | key | @data[key] }
  define_method(:[]=) { | key, value | @data[key]=value }

  def initialize values
    @data = Hash.new
    %w(username enabled is_admin tags).each do |meth|
      @data[meth.to_sym] = values[meth]
    end
  end
end

# class for storing favorites
class Favorites
  %w(id name user hashcode).each do |meth|
    define_method(meth) { @data[meth.to_sym] }
  end

  define_method(:[]) { | key | @data[key] }
  define_method(:[]=) { | key, value | @data[key]=value }

  def initialize values
    @data = Hash.new
    %w(id name user hashcode).each do |meth|
      @data[meth.to_sym] = values[meth]
    end
  end
end

class StorageElasticSearch
  # Required function, accepts a KibanaConfig object
  def initialize(config)
    @config = config
    @index = 'kibana'
    puts "Initializing elasticsearch module"
    @esm = Elasticsearchmod.new(@index,'permission')
    @esf = Elasticsearchmod.new(@index,'favorite')
    puts "Initializing elasticsearch for kibana storage..."
    if ! get_permissions(config::Auth_Admin_User)
      puts "Default Kibana admin user does not exist ... creating"
      set_permissions(config::Auth_Admin_User,config::Auth_Admin_Perms['tags'],true,true)
    end
  end

  # Required function, gets the user's permissions
  def get_permissions(username)
    p = @esm.get_by_id(username)
    if p
      perm = Permissions.new p
      return perm
    else
      return nil
    end
  end

  def get_all_permissions()
    perms = Array.new
    response = @esm.get_all()
    response.each do |item|
      perm = Permissions.new item
      perms << perm
    end
    return perms
  end

  # Required function, sets the user's permissions
  def set_permissions(username,tags,is_admin = false,is_enabled = true)
    values = {"username" => username, "tags" => tags, "is_admin" => is_admin}
    r = @esm.set_by_id(username, values)
    return true
  end

  def del_permissions(username)
    r = @esm.del_by_id(username)
  end

  # Required function, enables a user
  def enable_user(username)
    return false
  end

  # Required function, disables a user
  def disable_user(username)
    return false
  end

  # Sets a favorite
  def set_favorite(name,user,hashcode)
    id = (0...10).map{65.+(rand(26)).chr}.join
    values = {"id" => id, "name" => name, "user" => user, "hashcode" => hashcode}
    r = @esf.set_by_id(id, values)
    return r["ok"]
  end

  # Deletes a favorite
  def del_favorite(id)
    r = @esf.del_by_id(id)
    return r["ok"]
  end

  # Get the user's favorites
  def get_favorites(user)
    favorites = Array.new(0)
    response = @esf.get_records_with_term("user",user)
    response.each do |item|
      favorite = Favorites.new item
      favorites << favorite
    end
  end

  # Get a favorite
  def get_favorite(id)
    r = @esf.get_by_id(id)
    if r
      fav = Favorites.new r
      return fav
    else
      return nil
    end
  end

end

# Required function, returns the storage
# class for this module.
def get_storage_module(config)
  return StorageElasticSearch.new(config)
end
