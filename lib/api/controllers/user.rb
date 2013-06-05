require 'api/controllers/base'
module KAG
  module API
    module Controller
      class User < Base
        @class_key = 'User'


        def get
          if @params[:id]
            self.read(@params[:id])
          elsif @params[:username]
            @primary_key = :username
            self.read(@params[:username])
          else
            self.list
          end
        end

        def read(id)
          if @primary_key == :username
            user = ::User.where('authname = ? OR kag_user = ?',@params[:username],@params[:username]).first
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
            d[:clan_name] = user.clan.name if user.clan
            d.delete(:host)
            d.delete(:authname)
            d.delete(:nick)
            d[:rank] = user.rank

            limit = @params[:achievements_limit] || 20
            offset = @params[:achievements_offset] || 0
            d[:achievements] = {}
            user.achievements.limit(limit).offset(offset).each do |ach|
              d[:achievements][ach.code] = {
                  :name => ach.name,
                  :description => ach.description,
                  :code => ach.code
              }
            end
            limit = @params[:achievements_close_limit] || 20
            offset = @params[:achievements_close_offset] || 0
            d[:achievements_close] = user.achievements_close(limit,offset)

            limit = @params[:recent_matches_limit] || 10
            offset = @params[:recent_matches_offset] || 0
            d[:recent_matches] = user.recent_matches(limit,offset)

            limit = @params[:oppressors_limit] || 10
            offset = @params[:oppressors_offset] || 0
            d[:oppressors] = user.oppressors(limit,offset)
            limit = @params[:oppressing_limit] || 10
            offset = @params[:oppressing_offset] || 0
            d[:oppressing] = user.oppressing(limit,offset)
            self.success('',d)
          else
            self.failure('err_nf',user)
          end
        end

        def list
          limit = @params[:limit] || 20
          offset = @params[:offset] || 0
          w = @params.dup
          w.delete(:offset)
          w.delete(:limit)
          c = ::User.where(w).order('score DESC').limit(limit).offset(offset)
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