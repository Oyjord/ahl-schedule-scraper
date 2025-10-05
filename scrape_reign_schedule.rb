require 'ahl_scraper'
require 'json'

team_id = 403  # Ontario Reign

# Grab all available seasons
seasons = AhlScraper::Seasons.list

# Filter to just this year’s preseason + regular season
target_seasons = seasons.select { |s| [:preseason, :regular].include?(s.season_type) }

games = []

target_seasons.each do |season|
  season_games = AhlScraper::TeamGames.list(team_id, season.id).map do |g|
    {
      game_id: g.game_id,
      date: g.date,
      status: g.status,
      home_team: g.home_team[:city],
      home_score: g.home_score,
      away_team: g.away_team[:city],
      away_score: g.away_score,
      game_center_url: g.game_center_url,
      # These may not exist for future games, so wrap safely
      game_report_url: (g.respond_to?(:game_report_url) ? (g.game_report_url rescue nil) : nil),
      game_sheet_url: (g.respond_to?(:game_sheet_url) ? (g.game_sheet_url rescue nil) : nil),
      season_type: season.season_type.to_s  # ✅ tag each game
    }.compact
  end

  games.concat(season_games)
end

# Sort by date so preseason comes first, then regular season
games.sort_by! { |g| g[:date] }

File.write("reign_schedule.json", JSON.pretty_generate(games))
puts "✅ Schedule saved to reign_schedule.json"
