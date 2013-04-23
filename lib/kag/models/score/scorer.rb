module KAG
  class Scorer

    WIN_RATIO_MULTIPLIER = 400
    GENERIC_KILL_MULTIPLIER = 12
    KNIGHT_KILL_MULTIPLIER = 24
    ARCHER_KILL_MULTIPLIER = 16
    BUILDER_KILL_MULTIPLIER = 48

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
    #
    def score
      return 0 unless @user
      stats = @user.stats_as_hash
      wins = stats['wins'].to_i
      losses = stats['losses'].to_i

      if (wins+losses) > 5
        player_matches = wins+losses
        win_percentage = wins.to_f / player_matches.to_f
        total_matches = ::Match.where('stats IS NOT NULL AND ended_at IS NOT NULL').count
        percentage_of_matches = (player_matches.to_f / total_matches.to_f)
        win_multiplier = (percentage_of_matches * win_percentage) - (losses*0.03)
      else
        win_multiplier = 0
      end


      generic_kills = stats['kills'].to_i - stats['archer.kills'].to_i - stats['builder.kills'].to_i - stats['knight.kills'].to_i
      generic_deaths = stats['deaths'].to_i - stats['archer.deaths'].to_i - stats['builder.deaths'].to_i - stats['knight.deaths'].to_i

      score = 0
      if win_multiplier > 0
        #puts "#{@user.name} : #{wins.to_s}-#{losses.to_s} : #{player_matches.to_s} / #{total_matches.to_s} : #{percentage_of_matches.to_s} * #{win_percentage.to_s} : #{win_multiplier.to_s}"
        score += win_multiplier * WIN_RATIO_MULTIPLIER
      end

      b_wins = stats['builder.wins'].to_i
      b_losses = stats['builder.losses'].to_i
      score += b_wins # slight bonus to builder wins since builder is less dependent on k/d
      score -= b_losses/2 # slight detract to builder losses since builder is less dependent on k/d

      score += calc_kr_add(GENERIC_KILL_MULTIPLIER,generic_kills,generic_deaths)
      score += calc_kr_add(KNIGHT_KILL_MULTIPLIER,stats['knight.kills'].to_i,stats['knight.deaths'].to_i)
      score += calc_kr_add(ARCHER_KILL_MULTIPLIER,stats['archer.kills'].to_i,stats['archer.deaths'].to_i)
      score += calc_kr_add(BUILDER_KILL_MULTIPLIER,stats['builder.kills'].to_i,stats['builder.deaths'].to_i)

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