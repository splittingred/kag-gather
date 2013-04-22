module KAG
  class Scorer

    WIN_RATIO_MULTIPLIER = 600
    GENERIC_KILL_MULTIPLIER = 1.5
    KNIGHT_KILL_MULTIPLIER = 3
    ARCHER_KILL_MULTIPLIER = 2
    BUILDER_KILL_MULTIPLIER = 8

    def initialize(user)
      @user = user
    end

    ##
    # Calculate score.
    #
    # Subtract class-specific kills/deaths from main kills/deaths total before calculating
    #
    def self.score(user)
      scorer = self.new(user)
      scorer.score
    end


    ##
    # Score the user
    # TODO: Optimize the crap out of this, no need to do so many @user.stat calls, get em all in one call
    #
    def score
      return 0 unless @user
      wins = @user.stat('wins')
      losses = @user.stat('losses')

      if wins > 0 or losses > 0
        player_matches = wins+losses
        win_percentage = wins.to_f / player_matches.to_f
        total_matches = ::Match.where('stats IS NOT NULL').count
        percentage_of_matches = (player_matches.to_f / total_matches.to_f)
        win_multiplier = percentage_of_matches * win_percentage
      else
        win_multiplier = 0
      end

      kills = @user.stat('kills')
      deaths = @user.stat('deaths')
      kills_a = @user.stat('archer.kills')
      deaths_a = @user.stat('archer.deaths')
      kills_b = @user.stat('builder.kills')
      deaths_b = @user.stat('builder.deaths')
      kills_k = @user.stat('knight.kills')
      deaths_k = @user.stat('knight.deaths')

      generic_kills = kills-kills_a-kills_b-kills_k
      generic_deaths = deaths-deaths_a-deaths_b-deaths_k

      score = 0
      if win_multiplier > 0
        #puts "#{@user.name} : #{wins.to_s}-#{losses.to_s} : #{player_matches.to_s} / #{total_matches.to_s} : #{percentage_of_matches.to_s} * #{win_percentage.to_s} : #{win_multiplier.to_s}"
        score += win_multiplier * WIN_RATIO_MULTIPLIER
      end

      score += calc_kr_add(GENERIC_KILL_MULTIPLIER,generic_kills,generic_deaths)
      score += calc_kr_add(KNIGHT_KILL_MULTIPLIER,kills_k,deaths_k)
      score += calc_kr_add(ARCHER_KILL_MULTIPLIER,kills_a,deaths_a)
      score += calc_kr_add(BUILDER_KILL_MULTIPLIER,kills_b,deaths_b)

      @user.score = score
      @user.save
      score
    end

    def calc_kr_add(multiplier,kills,deaths)
      add = 0
      if kills > 0 or deaths > 0
        ratio = kills.to_f / (kills+deaths).to_f
        if ratio > 0
          add += ratio*multiplier
        end
      end
      add
    end
  end
end