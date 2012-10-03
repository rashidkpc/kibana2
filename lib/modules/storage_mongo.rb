require 'mongoid'

# MongoID class for storing permissions
class Permissions
  include Mongoid::Document
  field :username
  field :enabled, :type => Boolean
  field :is_admin, :type => Boolean
  field :tags, :type => Array
end

class StorageMongo
  # Required function, accepts a KibanaConfig object
  def initialize(config)
    @config = config
    @mongo_host = (defined? config::Mongo_host) ? config::Mongo_host : "127.0.0.1"
    @mongo_port = (defined? config::Mongo_port) ? config::Mongo_port : 27017
    @mongo_db = (defined? config::Mongo_db) ? config::Mongo_db : "kibana"
    puts "Initializing mongo (#{@mongo_host}:#{@mongo_port}/#{@mongo_db}) for kibana storage..."
    Mongoid.configure.master = Mongo::Connection.new(@mongo_host,@mongo_port).db(@mongo_db)
  end

  # Helper function
  def lookup_permissions(username)
    p = Permissions.where(:username => username)[0]
    return p
  end

  # Required function, gets the user's permissions
  def get_permissions(username)
    p = lookup_permissions(username)
    if p
      return p
    else
      return nil
    end
  end

  # Required function, sets the user's permissions
  def set_permissions(username,tags,is_admin = false)
    begin
      p = lookup_permissions(username)
      if !p
        raise "Username not found"
      end
      p[:tags] = tags
      p[:is_admin] = is_admin
      p.save!
      if !p.persisted?
        raise "Failed to save user data for #{username}"
      end
      return true
    rescue
      # TODO: log message?
      return false
    end
  end

  # Required function, enables a user
  def enable_user(username)
    begin
      p = get_permissions(username)
      if !p
        raise "Username not found"
      end
      p[:enabled] = true
      p.save!
      if !p.persisted?
        raise "Failed to save user data for #{username}"
      end
      return true
    rescue
      return false
    end
  end

  # Required function, disables a user
  def disable_user(username)
    begin
      p = get_permissions(username)
      if !p
        raise "Username not found"
      end
      p[:enabled] = false
      p.save!
      if !p.persisted?
        raise "Failed to save user data for #{username}"
      end
      return true
    rescue
      return false
    end
  end
end

# Required function, returns the storage
# class for this module.
def get_storage_module(config)
  return StorageMongo.new(config)
end
