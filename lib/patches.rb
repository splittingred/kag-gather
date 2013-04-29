require 'cinch'

class Hash
  @keys_not_used = nil
  def random_key
    @keys_not_used = self.dup if (!@keys_not_used or @keys_not_used.size == 0)
	  key = @keys_not_used.keys[rand(@keys_not_used.size)]
	  @keys_not_used.delete(key)
    key
  end
  def shuffle
    self.class[self.to_a.sample(self.length)]
  end

  def shuffle!
    self.replace(self.shuffle)
  end
end

module Cinch
  class User < Target
    def to_s
      self.data[:authname]
    end

    def to_i
      self.to_s.to_i
    end
  end

  class IRC
    def on_401(msg, events)
      # ERR_NOSUCHNICK
      user = User(msg.params[1])
      user.sync(:unknown?, true, true)
      msg.user.online = false if msg.user
      if @whois_updates.key?(user)
        user.end_of_whois(nil, true)
        @whois_updates.delete user
      end
    end
  end
end
