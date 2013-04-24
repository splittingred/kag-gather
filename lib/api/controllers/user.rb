require 'api/controllers/base'
module KAG
  module API
    module Controller
      class User < Base
        @@class_key = 'User'


        def get
          if @params[:id]
            self.read(@params[:id])
          elsif @params[:username]
            @@primary_key = :username
            self.read(@params[:username])
          else
            self.list
          end
        end

        def read(id)
          if @@primary_key == :username
            user = ::User.where("authname = ? OR kag_user = ?",@params[:username],@params[:username]).first
          else
            user = ::User.where(:id => id).first
          end
          if user
            d = SymbolTable.new(user.attributes)
            d[:stats] = {}
            user.stats.each do |s|
              d[:stats][s.name] = {
                  :times => s.value,
                  :rank => s.rank
              }
            end
            d[:stats][:matches] = user.matches.count
            d.delete(:host)
            d.delete(:authname)
            d.delete(:nick)
            d[:rank] = user.rank
            self.success('',d)
          else
            self.failure('err_nf',user)
          end
        end

        def list
          c = ::User.where(@params)
          if c
            us = []
            c.each do |u|
              ud = SymbolTable.new(u.attributes)
              ud.delete(:host)
              us << ud
            end
            self.success('',us)
          else
            self.failure('err_nf',c)
          end
        end

      end
    end
  end
end