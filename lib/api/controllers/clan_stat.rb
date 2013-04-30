require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Clan_stat < Base
        @@class_key = 'ClanStat'
        @@primary_key = :name

        def get
          name = @params[:name].to_s || ''
          if name.empty?
            self.failure('err_ns')
          else
            limit = @params[:limit] || 20
            times = ::ClanStat.where(:name => name).sum('value')
            clans_count = ::ClanStat.select('*,clans.name').joins(:clan).where(:clan_stats => {:name => name}).count
            clans = ::ClanStat.select('*,clans.name').joins(:clan).where(:clan_stats => {:name => name}).limit(limit).order('value DESC')
            list = []
            clans.each do |c|
              list << {
                  :clan => c.name,
                  :times => c.value
              }
            end
            self.collection(list,clans_count,{
                :name => name,
                :times => times,
            })
          end
        end
      end
    end
  end
end