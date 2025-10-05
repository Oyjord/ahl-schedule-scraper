require 'ahl_scraper'
require 'json'
require 'open-uri'
require 'nokogiri'

team_id       = 403
preseason_id  = 89
regular_id    = 90

def parse_goal_scorers(report_url, home_team, away_team)
  return { home: [], away: [] } unless report_url
  begin
    html = URI.open(report_url).read
    doc = Nokogiri::HTML(html)

    text = doc.text
    # 🔎 Write out the raw text so you can inspect it in workflow artifacts
    File.write("debug_report.txt", text)

    lines = text.split(/[\r\n]+/).map(&:strip)

    home_goals, away_goals = [], []

    lines.each do |line|
      # For now just print any line that mentions either team
      if line.include?(home_team) || line.include?(away_team)
        puts "LINE: #{line}"
      end
    end

    { home: home_goals, away: away_goals }
  rescue => e
    puts "⚠️ Failed to parse scorers from #{report_url}: #{e}"
    { home: [], away: [] }
  end
end

games = []

[
  { id: preseason_id, type: "preseason" },
  { id: regular_id,   type: "regular" }
].each do |season|
  AhlScraper::TeamGames.list(team_id, season[:id]).each do |g|
    game_hash = {
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

    # ✅ Enrich with goal scorers if Final
    if g.status.downcase.include?("final") && game_hash[:game_report_url]
      puts "ENRICHING #{g.game_id} with report #{game_hash[:game_report_url]}"
      scorers = parse_goal_scorers(game_hash[:game_report_url],
                                   game_hash[:home_team],
                                   game_hash[:away_team])
      game_hash[:home_goals] = scorers[:home]
      game_hash[:away_goals] = scorers[:away]
    end

    games << game_hash
  end
end

# Sort chronologically
games.sort_by! { |g| g[:date] }

File.write("reign_schedule.json", JSON.pretty_generate(games))
puts "✅ Schedule saved to reign_schedule.json"
