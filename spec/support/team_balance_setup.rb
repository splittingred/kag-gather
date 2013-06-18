module KAG
  module Test
    class TeamBalanceSetup
      attr_accessor :server,:queue,:match,:players,:listener,:parser

      def start_match(shuffle_teams = true)
        self.server = ::Server.new
        self.server.name = 'test'
        self.server.ip = '127.0.0.1'
        self.server.port = 50301
        self.server.password = '1234'
        unless self.server.save
          raise 'Failed to save server'
        end

        self.queue = ::GatherQueue.first

        player_list = {
            :killatron => 1460.22,
            :warrfork => 1000.82,
            :magnum357 => 797.32,
            :cpa3y => 894.9,
            :RaMmStEiN_2012 => 777.64,
            :SpideY => 757.17,
            :CrystalClear => 715.23,
            :splittingred => 665.11,
            :Urkeuse => 646.26,
            :Black0ut => 512.85,
        }
        KAG::Config.instance[:match_size] = 10

        self.players = []
        player_list.each do |p,s|
          u = ::User.new
          u.authname = p
          u.nick = p
          u.score = s
          u.kag_user = p
          if u.save
            p = ::GatherQueuePlayer.new
            p.gather_queue_id = self.queue.id
            p.user_id = u.id
            self.players << p
          end
        end

        self.match = ::Match.new({
           :server => self.server
        })
        self.match.setup_teams(self.players,shuffle_teams)
        unless self.match.save
          raise 'Failed to save match'
        end
        self.match
      end
    end
  end
end