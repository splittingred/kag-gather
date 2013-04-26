module KAG
  class Scorer

    def initialize(user)
      @user = user
      @ratios = SymbolTable.new({
        :win_ratio => 500,
        :generic_kill => 12,
        :knight_kill => 24,
        :archer_kill => 16,
        :builder_kill => 48,
        :builder_win => 1,
        :builder_loss => 2,
        :loss => 0.1,
        :death_weight => 2.00,
        :inactive_penalty_multiplier => 10,
      })
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
      score = 0
      stats = @user.stats_as_hash
      wins = stats['wins'].to_i
      losses = stats['losses'].to_i

      if (wins+losses) >= 5
        player_matches = wins+losses
        win_percentage = wins.to_f / player_matches.to_f
        loss_percentage = (100.00 - (win_percentage*100))/100.00
        total_matches = ::Match.where('stats IS NOT NULL AND ended_at IS NOT NULL').count
        percentage_of_matches = (player_matches.to_f / total_matches.to_f)
        win_multiplier = (percentage_of_matches * win_percentage) - (loss_percentage*@ratios[:loss])

        generic_kills = stats['kills'].to_i - stats['archer.kills'].to_i - stats['builder.kills'].to_i - stats['knight.kills'].to_i
        generic_deaths = stats['deaths'].to_i - stats['archer.deaths'].to_i - stats['builder.deaths'].to_i - stats['knight.deaths'].to_i

        if win_multiplier > 0
          #puts "#{@user.name} : #{wins.to_s}-#{losses.to_s} : #{player_matches.to_s} / #{total_matches.to_s} : #{percentage_of_matches.to_s} * #{win_percentage.to_s} : #{win_multiplier.to_s}"
          score += win_multiplier * @ratios[:win_ratio]
        end

        last_match = @user.matches.where(:end_votes => 0).last
        if last_match
          days_since_last_match = (Time.now - last_match.ended_at) / 86400
          if days_since_last_match > 4.00
            score -= (days_since_last_match * @ratios[:inactive_penalty_multiplier])
          end
        end

        b_wins = stats['builder.wins'].to_i
        b_losses = stats['builder.losses'].to_i
        score += (b_wins*@ratios[:builder_win]) # slight bonus to builder wins since builder is less dependent on k/d
        score -= (b_losses*@ratios[:builder_loss]) # slight detract to builder losses since builder is less dependent on k/d

        score += calc_kr_add(@ratios[:generic_kill],generic_kills,generic_deaths)
        score += calc_kr_add(@ratios[:knight_kill],stats['knight.kills'].to_i,stats['knight.deaths'].to_i)
        score += calc_kr_add(@ratios[:archer_kill],stats['archer.kills'].to_i,stats['archer.deaths'].to_i)
        score += calc_kr_add(@ratios[:builder_kill],stats['builder.kills'].to_i,stats['builder.deaths'].to_i)

        user_count = ::User.where('kag_user IS NOT NULL').count
        score = (score*user_count.to_f)/((user_count/7.2)*3.1337)
      else
        score = 0.00
      end

      score = score <= 0 ? 0 : score
      @user.score = score
      @user.save
      score
    end

    def calc_kr_add(multiplier,kills,deaths)
      add = 0
      if kills > 0 or deaths > 0
        ratio = kills.to_f / (kills+(deaths*@ratios[:death_weight])).to_f
        if ratio > 0
          add += ratio*multiplier
        end
      end
      add
    end
  end
end