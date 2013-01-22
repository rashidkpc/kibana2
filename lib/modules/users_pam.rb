require 'etc'
require 'rpam'

include Rpam

class UsersPam
  # Required function, accepts a KibanaConfig object
  def initialize(config)
  end

  # Required function, returns user's groups membership
  def membership(username)
    grlist = []
    begin
      userpw = Etc.getpwnam(username)
    rescue
      return grlist
    end
    begin
      usergr = Etc.getgrgid(userpw.gid)
      grlist.push(usergr.name)
    rescue
      # This shouldn't happen, if it does it means
      # someone was probably hand-editing the passwd/
      # group files and messed up. 
    end
    Etc.group { |g|
      if g.mem.index(username)
        grlist.push(g.name)
      end
    }
    return grlist.uniq.sort
  end

  # Required function, returns a list of all groups
  def groups()
    grlist = []
    Etc.group { |g|
      grlist.push(g.name)
    }
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
  return UsersPam.new(config)
end
