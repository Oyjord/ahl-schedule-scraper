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

    # AHL text reports usually list goals in <tr> or <li> rows containing "Goal"
    goal_rows = doc.css('tr, li, div').select { |el| el.text.include?("Goal") }

    home_goals = []
    away_goals = []

    goal_rows.each do |row|
      text = row.text.strip
      # Example text: "1. 12:34 1st - John Doe (Smith, Brown) ONT Goal"
      if text =~ /(\d+:\d+)\s+(\d\w+)\s+-\s+(.+?)\s+(.*?)/
        time = $1
        period = $2
        scorer = $3.strip
        assists = $4.strip
        line = "#{scorer} (#{period}, #{time})"
        line += " assisted by #{assists}" unless assists.empty?

        if text.include?(home_team)
          home_goals << line
        elsif text.include?(away_team)
          away_goals << line
        end
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
