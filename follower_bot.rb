require 'dotenv/load'
require 'json'
require 'httparty'

# Environment variables
github_user = ENV['github_user']
personal_github_token = ENV['personal_github_token']

# API URLs
follower_url = "https://api.github.com/users/#{github_user}/followers?per_page=100&page="
update_followed_user = 'https://api.github.com/user/following/%s'
# HTTP headers
headers = { 'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36' }

# Variables
current_followers = []
page = 1
follower_counter = 0

# Read existing followers from file
stored_followers = File.readlines('./followers.txt').map(&:chomp) rescue []

loop do
  sleep(1)
  response = HTTParty.get("#{follower_url}#{page}")
  unless response.code == 200
    puts "Error fetching followers on page #{page}: HTTP #{response.code}"
    puts "Aborting to prevent mass unfollows"
    exit
  end

  batch = JSON.parse(response.body)
  break if batch.empty?

  batch.each do |follower_info|
    next unless follower_info.is_a?(Hash) && follower_info['login']
    user = follower_info["login"]
    current_followers << user
  end
  page += 1
end

if current_followers < 5
  puts "You have less than 5 followers. Aborting to prevent mass unfollows."
  exit
end

new_followers = current_followers - stored_followers

new_followers.each do |user|
  sleep(1)
  response = HTTParty.put(
    update_followed_user % user,
    basic_auth: { username: github_user, password: personal_github_token},
    headers: headers
  )
  if response.code == 204
    puts "Followed new follower: #{user}"
    stored_followers << user
  else
    puts "Error following #{user}: #{response.body}"
  end
end

unfollowers = stored_followers - current_followers

unfollowers.each do |user|
  sleep(1)
  response = HTTParty.delete(
    update_followed_user % user,
    basic_auth: { username: github_user, password: personal_github_token },
    headers: headers
  )
  if response.code == 204
    puts "Unfollowed #{user} (no longer following you)"
    stored_followers.delete(user)
  else
    puts "Error unfollowing #{user}: #{response.body}"
  end
end

File.write('./followers.txt', stored_followers.sort.join("\n"))
File.write('follower_counter.txt', "#{stored_followers.size}\n")