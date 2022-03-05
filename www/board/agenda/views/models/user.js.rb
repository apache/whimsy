#
# Convenience access to user information (currently residing off of the
# Server.pending data structure).
#

class User
  def self.id
    Server.pending.userid || Server.userid
  end

  def self.initials
    Server.pending.initials || Server.userid
  end

  def self.firstname
    Server.pending.firstname || Server.firstname
  end

  def self.username
    Server.pending.username || Server.username
  end

  def self.role
    if Server.role
      Server.role
    elsif Server.pending and Server.pending.role
      Server.pending.role
    else
      :guest
    end
  end

  def self.role=(role)
    Server.role = role
  end
end
