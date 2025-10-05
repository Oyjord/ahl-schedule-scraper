require 'ahl_scraper'
require 'json'

team_id   = 403  # Ontario Reign
season_id = 89   # current season

games = AhlScraper::TeamGames.list(team_id, season_id).map do |g|
  {
    game_id: g.game_id,
    date: g.date,
    status: g.status,
    home_team: g.home_team[:city],
    home_score: g.home_score,
    away_team: g.away_team[:city],
    away_score: g.away_score,
    game_center_url: g.game_center_url,
    # Only include these if they don’t raise
    game_report_url: (g.respond_to?(:game_report_url) ? (g.game_report_url rescue nil) : nil),
    game_sheet_url: (g.respond_to?(:game_sheet_url) ? (g.game_sheet_url rescue nil) : nil)
  }.compact  # removes nil keys
end

File.write("reign_schedule.json", JSON.pretty_generate(games))
puts "✅ Schedule saved to reign_schedule.json"
