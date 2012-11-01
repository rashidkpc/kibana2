class AuthElasticSearch
  # Required function, accepts a KibanaConfig object
  def initialize(config)
    @config = config
    @index = 'kibana'
    @utype = 'user'
    @gtype = 'group'
    @qu_url = "#{Kelastic.index_path(@index)}/#{@utype}/_search"
    @qg_url = "#{Kelastic.index_path(@index)}/#{@gtype}/_search"
    puts "Initializing elasticsearch for kibana auth..."
    # Make sure the default admin user is present
    p = lookup_user(config::Auth_Admin_User)
    if (p == nil or p['total']!=1)
      puts "Adding default admin user #{config::Auth_Admin_User} ..."
      add_user(config::Auth_Admin_User,config::Auth_Admin_Pass)
    end
    
  end

  def lookup_user_groups(username)
    g = Kelastic.run(@qg_url, '{ "query": { "term": { "members": "'+username+'" } } }')
    return g['hits']
  end

  def lookup_user(username)
    p = Kelastic.run(@qu_url, '{ "query": { "term": { "username": "'+username+'" } } }')
    return p['hits']
  end

  # Required function, authenticates a username/password
  def authenticate(username,password)
    p = lookup_user(username)
    if p['total'] == 1
      hit = p['hits'][0]
      user = hit['_source']
      salt=user['salt']
      hashpass=Digest::SHA256.hexdigest(salt + password)
      if(hashpass == user['password'])
#        puts "#{username} succesfully auth'd"
        return true
      end
    end
#    puts "#{username} failed auth"
    return false
  end

  def add_user(username,password)
    c_url = "#{Kelastic.index_path(@index)}/#{@utype}/#{username}"
    salt = rand(65536)
    salt = salt.to_s(16)
    hashpass = Digest::SHA256.hexdigest(salt + password)
    values = {"username" => username, "password" => hashpass, "salt" => salt}
    query = values.to_json
    result  = Kelastic.run(c_url, query)
  end

  # TODO: This should update the groups list
  def add_user_2group(username,group)
    c_url = "#{Kelastic.index_path(@index)}/#{@gtype}/#{group}/_update}"
    query = '{ "script" : "ctx._source.members += username",
               "params" : {"username" : "'+username+'"},
               "upsert" : {"group" : "'+group+'", "members" : ["'+username+'"], "tags" : []}
             }'
    result  = Kelastic.run(c_url, query)
  end

  def rm_user_from_group(username,group)
    c_url = "#{Kelastic.index_path(@index)}/#{@gtype}/#{group}/_update}"
    query = '{ "script" : "ctx._source.members.remove(username)", "params" : {"username" : "'+username+'"}}'
    result  = Kelastic.run(c_url, query)
  end

  def add_group(group)
    c_url = "#{Kelastic.index_path(@index)}/#{@gtype}/#{group}}"
    values = {"group" => group, "members" => [], "tags" => []}
    query = values.to_json
    result  = Kelastic.run(c_url, query)

  end

  # Required function, returns user's groups membership
  def membership(username)
    grlist = []
    g = lookup_user_groups(username)
    if g['total'] >= 1
      g['hits'].each do |hit|
        grlist << hit['_id']
      end
    end
    return grlist.sort
  end

  # Required function, returns a list of all groups
  def groups()
    grlist = []
    return grlist.uniq.sort
  end
end

# Required function, returns the auth
# class for this module.
def get_auth_module(config)
  return AuthElasticSearch.new(config)
end
