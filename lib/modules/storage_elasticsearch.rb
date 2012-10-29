
# MongoID class for storing permissions
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

class StorageElasticSearch
  # Required function, accepts a KibanaConfig object
  def initialize(config)
    @config = config
    @index = 'kibana'
    @type = 'permission'
    @q_url = "#{Kelastic.index_path(@index)}/#{@type}/_search"
    puts "Initializing elasticsearch for kibana storage..."
    result  = Kelastic.run(@q_url, '{}')
    if result['status'] == 404 
      puts "Kibana index does not exist ... creating and populating with default admin account"
      c_url = "#{Kelastic.index_path(@index)}/#{@type}/1"
      values = config::Auth_Admin_Perms
      values["username"] = config::Auth_Admin_User
      query = values.to_json
      result  = Kelastic.run(c_url, query)
      # FIXME: Make sure this was successful
    end
  end

  # Helper function
  def lookup_permissions(username)
    p = Kelastic.run(@q_url, '{ "query": { "term": { "username": "'+username+'" } } }')
    p = p['hits']
    return p
  end

  # Required function, gets the user's permissions
  def get_permissions(username)
    response = lookup_permissions(username)
    p = response
    if p['total'] == 1
      hit = p['hits'][0]
      perm = Permissions.new hit['_source']
      return perm
    else
      return nil
    end
  end

  def get_all_permissions()
    perms = Array.new
    response = Kelastic.run(@q_url, '{}')
    response['hits']['hits'].each do |hit|
      perm = Permissions.new hit['_source']
      perms << perm
    end
    return perms
  end

  # Required function, sets the user's permissions
  def set_permissions(username,tags,is_admin = false)
    c_url = "#{Kelastic.index_path(@index)}/#{@type}"
    values = {"username" => username, "tags" => tags, "is_admin" => is_admin}
    query = values.to_json
    result  = Kelastic.run(c_url, query)
    return false
  end

  # Required function, enables a user
  def enable_user(username)
    return false
  end

  # Required function, disables a user
  def disable_user(username)
    return false
  end
end

# Required function, returns the storage
# class for this module.
def get_storage_module(config)
  return StorageElasticSearch.new(config)
end
