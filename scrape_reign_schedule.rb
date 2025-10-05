require 'ahl_scraper'
require 'json'

team_id   = 403  # Ontario Reign
season_id = 89   # current regular season (check with AhlScraper::Seasons.list if this changes)

games = AhlScraper::TeamGames.list(team_id, season_id).map do |g|
  {
    game_id: g.game_id,
    date: g.date,                       # e.g. "Fri, Oct 10 2025"
    status: g.status,                   # "Scheduled", "Final", "In Progress"
    home_team: g.home_team[:city],
    home_score: g.home_score,
    away_team: g.away_team[:city],
    away_score: g.away_score,
    game_center_url: g.game_center_url, # official AHL GameCenter link
    game_report_url: g.game_report_url, # text game report
    game_sheet_url: g.game_sheet_url    # official game sheet PDF
  }
end

File.write("reign_schedule.json", JSON.pretty_generate(games))
puts "✅ Schedule saved to reign_schedule.json"
