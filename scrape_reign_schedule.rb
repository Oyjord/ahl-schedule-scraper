require 'ahl_scraper'
require 'json'

team_id       = 403
preseason_id  = 89
regular_id    = 90

games = []

[
  { id: preseason_id, type: "preseason" },
  { id: regular_id,   type: "regular" }
].each do |season|
  AhlScraper::TeamGames.list(team_id, season[:id]).each do |g|
    games << {
      game_id: g.game_id,
      date: g.date,
      status: g.status,
      home_team: g.home_team[:city],
      home_score: g.home_score,
      away_team: g.away_team[:city],
      away_score: g.away_score,
      game_center_url: g.game_center_url,
      game_report_url: (g.respond_to?(:game_report_url) ? (g.game_report_url rescue nil) : nil),
      game_sheet_url: (g.respond_to?(:game_sheet_url) ? (g.game_sheet_url rescue nil) : nil),
      season_type: season[:type]
    }.compact
  end
end

# Sort by date string (or by parsed Date if you prefer)
games.sort_by! { |g| g[:date] }

File.write("reign_schedule.json", JSON.pretty_generate(games))
puts "✅ Schedule saved to reign_schedule.json"
