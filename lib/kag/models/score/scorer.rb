module KAG
  class Scorer

    def initialize(user)
      @user = user
      @ratios = SymbolTable.new({
        :win_ratio => 20,
        :loss_ratio => 7,
        :generic_kill => 6,
        :generic_death => 6,

        :knight_kill => 12,
        :knight_death => 6,
        :archer_kill => 3,
        :archer_death => 18,
        :builder_kill => 24,
        :builder_death => 12,

        :builder_win => 2.5,
        :builder_loss => 1.75,

        :loss => 2.0,
        :inactive_penalty_multiplier => 20,
        :inactive_penalty_days => 5.00,
        :match_percentage_multiplier => 500,
        :minimum_matches => 5,
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

      if (wins+losses) >= @ratios[:minimum_matches]

        total_matches = ::Match.where('stats IS NOT NULL AND ended_at IS NOT NULL').count
        player_matches = wins+losses
        percentage_of_matches = (player_matches.to_f / total_matches.to_f)

        win_percentage = wins.to_f / player_matches.to_f
        loss_percentage = (100.00 - (win_percentage*100))/100.00
        if loss_percentage > 0
          win_multiplier = (win_percentage) / (loss_percentage*@ratios[:loss])
        else
          win_multiplier = win_percentage
        end
        puts "#{@user.name}: (W: #{win_percentage.to_s}) - (L: #{loss_percentage.to_s} * #{@ratios[:loss].to_s}) == #{win_multiplier.to_s}"

        generic_kills = stats['kills'].to_i - stats['archer.kills'].to_i - stats['builder.kills'].to_i - stats['knight.kills'].to_i
        generic_deaths = stats['deaths'].to_i - stats['archer.deaths'].to_i - stats['builder.deaths'].to_i - stats['knight.deaths'].to_i

        if wins > 0 or losses > 0
          win_adder = (wins * @ratios[:win_ratio]) - (losses * @ratios[:loss_ratio]) + (percentage_of_matches * @ratios[:match_percentage_multiplier])
          win_adder2 = win_adder * win_multiplier
          score += win_adder2

          puts "#{@user.name}:  (#{wins.to_s} * #{@ratios[:win_ratio].to_s}) - (#{losses.to_s} * #{@ratios[:loss_ratio].to_s}) + (#{percentage_of_matches.to_s} * #{@ratios[:match_percentage_multiplier].to_s}) == #{win_adder.to_s} * #{win_multiplier.to_s} == #{win_adder2.to_s}"
        end

        last_match = @user.matches.where('end_votes = 0 AND ended_at IS NOT NULL').last
        if last_match
          days_since_last_match = (Time.now - last_match.ended_at) / 86400
          if days_since_last_match > @ratios[:inactive_penalty_days]
            score -= (days_since_last_match * @ratios[:inactive_penalty_multiplier])
          end
        end

        b_wins = stats['builder.wins'].to_i
        b_losses = stats['builder.losses'].to_i
        score += (b_wins*@ratios[:builder_win]) # slight bonus to builder wins since builder is less dependent on k/d
        score -= (b_losses*@ratios[:builder_loss]) # slight detract to builder losses since builder is less dependent on k/d

        score += calc_kr_add(@ratios[:generic_kill],@ratios[:generic_death],generic_kills,generic_deaths)
        score += calc_kr_add(@ratios[:knight_kill],@ratios[:knight_death],stats['knight.kills'].to_i,stats['knight.deaths'].to_i)
        score += calc_kr_add(@ratios[:archer_kill],@ratios[:archer_death],stats['archer.kills'].to_i,stats['archer.deaths'].to_i)
        score += calc_kr_add(@ratios[:builder_kill],@ratios[:builder_death],stats['builder.kills'].to_i,stats['builder.deaths'].to_i)

        #user_count = ::User.where('kag_user IS NOT NULL AND status = "active"').count
        #score = (score*user_count.to_f)/((user_count/7.2)*3.1337)
        #score = score * win_multiplier
      else
        score = 0.00
      end

      score = score - 1000 if user.name == 'killatron46'

      score = score <= 0 ? 0 : score
      @user.score = score
      @user.save
      score
    end

    def calc_kr_add(kill_multiplier,death_multiplier,kills,deaths)
      add = 0
      if kills > 0 or deaths > 0
        add += kills * (kill_multiplier / 50)
        add -= deaths * (death_multiplier / 50)
      end
      add
    end
  end
end