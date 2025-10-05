require 'ahl_scraper'
require 'json'
require 'open-uri'
require 'nokogiri'

TEAM_ID       = 403
PRESEASON_ID  = 89
REGULAR_ID    = 90

def parse_goal_scorers(summary_url, home_team, away_team)
  return { home: [], away: [] } unless summary_url
  begin
    html = URI.open(summary_url).read
    doc  = Nokogiri::HTML(html)

    home_goals, away_goals = [], []

    # Inspect the page: the goal summary is usually in a table with class "goal-summary"
    doc.css('table.goal-summary tr').each do |row|
      cells = row.css('td').map { |td| td.text.strip }
      next if cells.empty? || cells[0] == "Per"

      period  = cells[0]
      time    = cells[1]
      team    = cells[2]
      scorer  = cells[3]
      assists = cells[4]

      entry = "#{scorer} (#{period} #{time})"
      entry += " assisted by #{assists}" unless assists.nil? || assists.empty?

      puts "PARSED: #{entry}"

      if team.include?(home_team)
        home_goals << entry
      else
        away_goals << entry
      end
    end

    { home: home_goals, away: away_goals }
  rescue => e
    puts "⚠️ Failed to parse scorers from #{summary_url}: #{e}"
    { home: [], away: [] }
  end
end

games = []

[
  { id: PRESEASON_ID, type: "preseason" },
  { id: REGULAR_ID,   type: "regular" }
].each do |season|
  AhlScraper::TeamGames.list(TEAM_ID, season[:id]).each do |g|
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

games.sort_by! { |g| g[:date] }

File.write("reign_schedule.json", JSON.pretty_generate(games))
puts "✅ Schedule saved to reign_schedule.json"
