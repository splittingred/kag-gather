require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Clan_stat < Base
        @class_key = 'ClanStat'
        @primary_key = :name

        def get
          name = @params[:name].to_s || ''
          if name.empty?
            self.failure('err_ns')
          else
            limit = @params[:limit] || 10
            offset = @params[:offset] || 10
            times = ::ClanStat.where(:name => name).sum('value')
            clans_count = ::ClanStat.select('*,clans.name').joins(:clan).where(:clan_stats => {:name => name}).count
            clans = ::ClanStat.select('*,clans.name').joins(:clan).where(:clan_stats => {:name => name}).limit(limit).offset(offset).order('value DESC')
            list = []
            clans.each do |c|
              times = ::UserStat.where(:name => name).sum('value')
              users = ::UserStat.select('*,users.kag_user').joins(:user).where(:user_stats => {:name => name},:users => {:clan_id => c.id}).limit(5).order('value DESC')

              user_list = []
              users.each do |u|
                user_list << {
                    :user => u.kag_user,
                    :times => u.value
                }
              end
              list << {
                  :clan => c.name,
                  :times => c.value,
                  :users => user_list
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