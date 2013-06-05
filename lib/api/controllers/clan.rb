require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Clan < Base
        @class_key = 'Clan'


        def get
          if @params[:id]
            self.read(@params[:id])
          elsif @params[:name]
            @primary_key = :name
            self.read(@params[:name])
          else
            self.list
          end
        end

        def read(id)
          if @primary_key == :name
            clan = ::Clan.where('name = ?',@params[:name]).first
          else
            clan = ::Clan.where(:id => id).first
          end
          if clan
            d = SymbolTable.new(clan.attributes)
            d[:stats] = {}
            clan.stats.each do |s|
              d[:stats][s.name] = {
                  :times => s.value,
                  :rank => s.rank
              }
            end
            d[:users] = clan.users_as_hash
            d[:rank] = clan.rank
            self.success('',d)
          else
            self.failure('err_nf',clan)
          end
        end

        def list
          c = ::Clan.where(@params).order('score DESC').limit(20)
          if c
            us = []
            c.each do |u|
              ud = SymbolTable.new(u.attributes)
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