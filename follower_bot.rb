require 'dotenv/load'
require 'json'
require 'httparty'

# Environment variables
github_user = ENV['github_user']
personal_github_token = ENV['personal_github_token']

# API URLs
follower_url = "https://api.github.com/users/#{github_user}/followers?page="
update_followed_user = 'https://api.github.com/user/following/%s'

# Variables
page = 1
follower_counter = 0

# Read existing followers from file
follower_txt_lists = File.readlines('./followers.txt').map(&:chomp) rescue []

File.open('./followers.txt', 'a') do |file_handler|
  loop do
    #delay pages
    sleep(1)
    response = HTTParty.get(follower_url + page.to_s)
    if response.code == 200
      follower_lists = JSON.parse(response.body)
      puts "Follower data: #{follower_lists.inspect}"
      break if follower_lists.empty?

      follower_counter += follower_lists.size
      follower_lists.each do |follower_info|
        puts "Processing follower info: #{follower_info.inspect}"
        if follower_info.is_a?(Hash) && follower_info.key?('login')
          user = follower_info["login"]
          next if follower_txt_lists.include?(user)

          headers = { 'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36' }
          put_response = HTTParty.put(update_followed_user % user,
                                      basic_auth: { username: github_user, password: personal_github_token },
                                      headers: headers)
          if put_response.code == 204
            puts "User: #{user} has been followed!"
            file_handler.puts(user)
          else
            puts "Error when following user #{user}: #{put_response.body}"
          end
          # Delay after following each user
          sleep(1)
        else
          puts "Unexpected data format for user: #{follower_info.inspect}"
        end
      end
    else
      puts "Error fetching follower data: HTTP #{response.code}"
    end
    page += 1
  end
end

File.write('follower_counter.txt', follower_counter.to_s + "\n")
puts "\nFollowing users from your followers list is done!"
