require 'kagerator'
require 'kag/user/user'

module KAG
  module User
    class Linker
      def self.unlinked?(user)
        user = KAG::User::User.new(user)
        if user
          if user[:kag_user]
            if user[:kag_user].nil? or user[:kag_user].to_s.empty?
              true
            else
              user[:kag_user]
            end
          else
            true
          end
        else
          true
        end
      end

      def self.link(user,username,password)
        authed = Kagerator.authenticate(username,password)
        if authed
          u = KAG::User::User.new(user)
          u[:kag_user] = username
          u.save
          user.send("Your account is now successfully linked from the IRC user #{user.authname.to_s} to the KAG user #{u[:kag_user].to_s}.")
        else
          user.send("Invalid username/password. Please try again.")
        end
      end

      def self.unlink(user,username)
        u = KAG::User::User.new(user)
        if u[:kag_user] and u[:kag_user].to_s == username.to_s
          account = u[:kag_user]
          u.delete(:kag_user)
          u.save
          user.send("Account #{user.authname.to_s} unlinked from KAG account #{account.to_s}")
        else
          user.send("Account #{user.authname.to_s} not linked to KAG account #{username}. Please try again.")
        end
      end
    end
  end
end