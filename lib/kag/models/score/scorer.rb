module KAG
  class Scorer

    S_WIN = 8
    S_LOSS = 5

    S_GENERIC_KILL = 10
    S_GENERIC_DEATH = 5

    S_KNIGHT_KILL = 10
    S_KNIGHT_DEATH = -3

    S_ARCHER_KILL = 5
    S_ARCHER_DEATH = -10

    S_BUILDER_KILL = 20
    S_BUILDER_DEATH = -4

    ####
    # Calculate score.
    #
    # Subtract class-specific kills/deaths from main kills/deaths total before calculating
    #

    def self.score(user)
      wins = user.stat('wins')
      losses = user.stat('losses')

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

      score = (wins*S_WIN)+(losses*-S_LOSS)
      score += generic_kills*S_GENERIC_KILL if generic_kills > 0
      score += generic_deaths*S_GENERIC_DEATH if generic_deaths > 0
      score += kills_k*S_KNIGHT_KILL
      score += deaths_k*S_KNIGHT_DEATH
      score += kills_a*S_ARCHER_KILL
      score += deaths_a*S_ARCHER_DEATH
      score += kills_b*S_BUILDER_KILL
      score += deaths_b*S_BUILDER_DEATH
    end
  end
end