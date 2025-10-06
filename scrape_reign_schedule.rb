require 'ahl_scraper'
require 'json'
require 'open-uri'
require 'nokogiri'

TEAM_ID       = 403
PRESEASON_ID  = 89
REGULAR_ID    = 90

def parse_goal_scorers(report_url, home_team, away_team)
  return { home: [], away: [] } unless report_url
  begin
    html = URI.open(report_url).read
    doc  = Nokogiri::HTML(html)

    text  = doc.text
    lines = text.split('.').map(&:strip)

    # Normalize whitespace: replace non-breaking spaces and collapse multiple spaces
    lines.map! { |line| line.gsub(/\u00A0/, ' ').squeeze(' ') }

    home_goals, away_goals = [], []

    lines.each do |line|
      puts "DEBUG LINE: #{line.inspect}"
      tokens = line.split(',').map(&:strip)
      puts "DEBUG TOKENS: #{tokens.inspect}"

      # Bulletproof fallback for malformed goal lines like "2, Ontario, Pinelli 1 3:22(SH)"
      if tokens.size == 3 && tokens[2].include?(':') && tokens[2].include?('(')
  period_number = tokens[0]
  team = tokens[1]
  scorer_parts = tokens[2].split(/\s+/)
  scorer = scorer_parts[0..-3].join(' ')
  time = scorer_parts[-2]
  strength = scorer_parts[-1].gsub(/[()]/, '')

  period_label = case period_number
                 when "1" then "1st Period"
                 when "2" then "2nd Period"
                 when "3" then "3rd Period"
                 else "#{period_number}th Period"
                 end

  entry = "#{scorer} (#{period_label} #{time}) [#{strength}]"
        puts "TOKEN PARSED: #{entry}"

        if team == home_team
          home_goals << entry
        elsif team == away_team
          away_goals << entry
        else
          puts "⚠️ Unknown team: #{team}"
        end
        next
      end

      # Original structured goal line parser
     match = line.match(/(?:(\d+(?:st|nd|rd|th))\s+Period-)?\d+,\s*(#{Regexp.escape(home_team)}|#{Regexp.escape(away_team)}),\s*(.+?)\s*,\s*(\d{1,2}:\d{2}(?:\s*(?:EN|SH|PP))?)/)

if match
  period_raw = match[1] # "1st", "2nd", etc.
  team = match[2]
  scorer_and_assists = match[3].strip
  time = match[4].strip

  scorer = scorer_and_assists.split(',').first.strip
  assists = scorer_and_assists.split(',')[1..]&.map(&:strip)&.join(', ')

  entry = "#{scorer} (#{time})"
  entry += " assisted by #{assists}" if assists && !assists.empty?
  entry += " [#{period_raw} Period]" if period_raw

  puts "PARSED: #{entry}"

        if team == home_team
          home_goals << entry
        else
          away_goals << entry
        end
      else
        puts "UNMATCHED LINE: #{line}"
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
      game_summary_url: "https://theahl.com/stats/game-summary/#{g.game_id}",
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
