module KAG
  class Scorer

    WIN_RATIO_MULTIPLIER = 600
    GENERIC_KILL_MULTIPLIER = 1
    KNIGHT_KILL_MULTIPLIER = 4
    ARCHER_KILL_MULTIPLIER = 2
    BUILDER_KILL_MULTIPLIER = 8

    ##
    # Calculate score.
    #
    # Subtract class-specific kills/deaths from main kills/deaths total before calculating
    #
    def self.score(user)
      wins = user.stat('wins')
      losses = user.stat('losses')

      if wins > 0 or losses > 0
        player_matches = wins+losses
        win_percentage = wins.to_f / player_matches.to_f
        total_matches = ::Match.count
        percentage_of_matches = (player_matches.to_f / total_matches.to_f)
        win_multiplier = percentage_of_matches * win_percentage
      else
        win_multiplier = 0
      end

      kills = user.stat('kills')
      deaths = user.stat('deaths')
      kills_a = user.stat('archer.kills')
      deaths_a = user.stat('archer.deaths')
      kills_b = user.stat('builder.kills')
      deaths_b = user.stat('builder.deaths')
      kills_k = user.stat('knight.kills')
      deaths_k = user.stat('knight.deaths')


      generic_kills = kills-kills_a-kills_b-kills_k
      generic_deaths = deaths-deaths_a-deaths_b-deaths_k

      score = 0
      if win_multiplier > 0
        #puts "#{user.name} : #{wins.to_s}-#{losses.to_s} : #{player_matches.to_s} / #{total_matches.to_s} : #{percentage_of_matches.to_s} * #{win_percentage.to_s} : #{win_multiplier.to_s}"
        score += win_multiplier * WIN_RATIO_MULTIPLIER
      end

      if generic_kills > 0 or generic_deaths > 0
        gkr = generic_kills.to_f / (generic_kills+generic_deaths).to_f
        if gkr > 0
          score += gkr*GENERIC_KILL_MULTIPLIER
        end
      end

      if kills_k > 0 or deaths_k > 0
        kkr = kills_k.to_f / (kills_k+deaths_k).to_f
        if kkr > 0
          score += kkr*KNIGHT_KILL_MULTIPLIER
        end
      end

      if kills_a > 0 or deaths_a > 0
        akr = kills_a.to_f / (kills_a+deaths_a).to_f
        if akr > 0
          score += akr*ARCHER_KILL_MULTIPLIER
        end
      end

      if kills_b > 0 or deaths_b > 0
        bkr = kills_b.to_f / (kills_b+deaths_b).to_f
        if bkr > 0
          score += bkr*BUILDER_KILL_MULTIPLIER
        end
      end

      user.score = score
      user.save
      score
    end
  end
end