############################################################
#### IMPORT phpBB to Discourse
####
#### originally created for facebook by Sander Datema (info@sanderdatema.nl)
#### forked by Claus F. Strasburger ( http://about.me/cfstras )
####
#### version 0.1
############################################################

############################################################
#### Description
############################################################
#
# This rake task will import all posts and comments of a
# phpBB Forum into Discourse.
#
############################################################
#### Prerequisits
############################################################
#
# - Add this to your Gemfile:
#   gem 'mysql2', require: false
# - Edit the configuration file config/import_phpbb.yml

############################################################
#### The Rake Task
############################################################

require 'mysql2'

desc "Import posts and comments from a phpBB Forum"
task "import:phpbb" => 'environment' do
  # Import configuration file
  @config = YAML.load_file('config/import_phpbb.yml')
  TEST_MODE = @config['test_mode']
  DC_ADMIN = @config['discourse_admin']

  if TEST_MODE then puts "\n*** Running in TEST mode. No changes to Discourse database are made\n".yellow end

  # Some checks
  # Exit rake task if admin user doesn't exist
  DC_ADMIN = Discourse.system_user
  #unless dc_user_exists(DC_ADMIN) then
  #  puts "\nERROR: The admin user #{DC_ADMIN} does not exist".red
  #  exit_script
  #end

  begin
    sql_connect

    sql_fetch_users
    sql_fetch_posts

    if TEST_MODE then
      require 'irb'
      ARGV.clear
      IRB.start
      exit_script # We're done
    else
      # Create users in Discourse
      dc_create_users_from_phpbb_users

      # Backup Site Settings
      dc_backup_site_settings

      # Then set the temporary Site Settings we need
      dc_set_temporary_site_settings

      # Create and/or set Discourse category
      dc_category = dc_get_or_create_category(DC_CATEGORY_NAME, DC_ADMIN)

      # Import Facebooks posts into Discourse
      fb_import_posts_into_dc(dc_category)

      # Restore Site Settings
      dc_restore_site_settings
    end
  ensure
    @sql.close if @sql
  end
  puts "\n*** DONE".green
  # DONE!
end


############################################################
#### Methods
############################################################

def sql_connect
  begin
    Mysql2::Client.new(:host => "localhost", :username => "root")
    @sql = Mysql2::Client.new(:host => @config['sql_server'], :username => @config['sql_user'],
      :password => @config['sql_password'], :database => @config['sql_database'])
  rescue Mysql2::Error => e
    puts "\nERROR: Connection to Database failed\n#{e.message}".red
    exit_script
  end

  puts "\nConnected to SQL DB".green
end

def sql_fetch_posts
  @phpbb_posts ||= [] # Initialize if needed
  offset = 0
  time_of_last_imported_post = until_time

  # Fetch Facebook posts in batches and download writer/user info
  loop do
    query = "SELECT t.topic_id, t.topic_title,
      u.username, u.user_id,
      f.forum_name,
      p.post_time, p.post_edit_time,
      p.post_id,
      p.post_text
      FROM phpbb_posts p
      JOIN phpbb_topics t ON t.topic_id=p.topic_id
      JOIN phpbb_users u ON u.user_id=p.poster_id
      JOIN phpbb_forums f ON t.forum_id=f.forum_id
      ORDER BY topic_id ASC, topic_title ASC, post_id ASC
      LIMIT #{offset},500;"
    result = @sql.query(query)

    break if result.count == 0 # No more posts to import

    # Add the results of this batch to the rest of the imported posts
    @phpbb_posts << result

    puts "Batch: #{result.count.to_s} posts (since "+
      "#{unix_to_human_time(result[-1]['post_time'])} until "+
      "#{unix_to_human_time(result[0]['post_time'])})"
    time_of_last_imported_post = result[-1]['post_time']

    offset += result.count

    result.each do |post|
      sql_fetch_user(post) # Extract the poster from the post
    end
  end

  puts "\nAmount of posts: #{@phpbb_posts.count.to_s}"
end

def sql_fetch_users(post)
  @phpbb_users ||= [] # Initialize if needed

  offset = 0
  loop do
    users = @sql.query "SELECT * 
      FROM `phpbb_users` 
      ORDER BY `user_id` ASC
      LIMIT #{offset}, 50;"
    break if users.count == 0
    @phpbb_users << users
    offset += users.count
  end
  puts "Amount of users: #{@phpbb_users.count.to_s}"
end

def sql_import_posts(dc_category)
  #TODO
  post_count = 0
  @phpbb_posts.each do |phpbb_post|
    post_count += 1

    # Get details of the writer of this post
    user = @phpbb_users.find {|k| k['user_id'] == phpbb_post['user_id'].to_s}

    # Get the Discourse user of this writer
    dc_user = dc_get_user(phpbb_username_to_dc(user['username_clean']))
    category = dc_get_or_create_category(
      phpbb_post['forum_name'].gsub(' ','-').downcase, DC_ADMIN)
    topic_title = phpbb_post['topic_title']
    # Remove new lines and replace with a space
    # topic_title = topic_title.gsub( /\n/m, " " )

    # some progress
    progress = post_count.percent_of(@phpbb_posts.count).round.to_s
    puts "[#{progress}%]".blue + " Creating topic '" + topic_title.blue #+ "' (#{topic_created_at})"

    # create!
    post_creator = PostCreator.new(dc_user,
                                   raw: phpbb_post['post_text'],
                                   title: topic_title,
                                   topic_id: phpbb_post['topic_id'],
                                   archetype: 'regular',
                                   category: category,
                                   created_at: Time.at(phpbb_post['post_time']),
                                   updated_at: Time.at(phpbb_post['post_edit_time']))
    post = post_creator.create
    
    topic_id = post.topic.id

    # Everything set, save the topic
    unless post_creator.errors.present? then
      post_serializer = PostSerializer.new(post, scope: true, root: false)
      post_serializer.topic_slug = post.topic.slug if post.topic.present?
      post_serializer.draft_sequence = DraftSequence.current(dc_user, post.topic.draft_key)

      puts " - Post #{phpbb_post['post_id']} created".green
    else # Skip if not valid for some reason
      puts "Contents of topic from post #{phpbb_post['post_id']} failed to import, #{post_creator.errors.messages[:base]}".red
    end
  end
end


# Returns the Discourse category where imported Facebook posts will go
def dc_get_or_create_category(name, owner)
  if Category.where('name = ?', name).empty? then
    puts "Creating category '#{name}'".yellow
    owner = User.where('username = ?', owner).first
    category = Category.create!(name: name, user_id: owner.id)
  else
    puts "Category '#{name}' exists"
    category = Category.where('name = ?', name).first
  end
end

# Create a Discourse user with Facebook info unless it already exists
def dc_create_users_from_phpbb_users
  #TODO
  @phpbb_users.each do |phpbb_user|
    # Setup Discourse username
    dc_username = phpbb_username_to_dc(phpbb_user['username_clean'])

    # Create email address for user
    if phpbb_user['user_email'].nil? then
      dc_email = dc_username + "@dc.q1cc.net"
    else
      dc_email = phpbb_user['user_email']
    end

    # Create user if it doesn't exist
    if User.where('username = ?', dc_username).empty? then
      dc_user = User.create!(username: dc_username,
                             name: phpbb_user['username'],
                             email: dc_email,
                             approved: true,
                             approved_by_id: DC_ADMIN.id)

      #TODO: add CAS auth
      # Create Facebook credentials so the user could login later and claim his account
      # FacebookUserInfo.create!(user_id: dc_user.id,
      #                         facebook_user_id: fb_writer['id'].to_i,
      #                         username: fb_writer['username'],
      #                         first_name: fb_writer['first_name'],
      #                         last_name: fb_writer['last_name'],
      #                         name: fb_writer['name'].tr(' ', '_'),
      #                         link: fb_writer['link'])*/
      puts "User #{phpbb_user['name']} (#{dc_username} / #{dc_email}) created".green
    end
  end
end

# Backup site settings
def dc_backup_site_settings
  @site_settings = {}
  @site_settings['unique_posts_mins'] = SiteSetting.unique_posts_mins
  @site_settings['rate_limit_create_topic'] = SiteSetting.rate_limit_create_topic
  @site_settings['rate_limit_create_post'] = SiteSetting.rate_limit_create_post
  @site_settings['max_topics_per_day'] = SiteSetting.max_topics_per_day
  @site_settings['title_min_entropy'] = SiteSetting.title_min_entropy
  @site_settings['body_min_entropy'] = SiteSetting.body_min_entropy
end

# Restore site settings
def dc_restore_site_settings
  SiteSetting.send("unique_posts_mins=", @site_settings['unique_posts_mins'])
  SiteSetting.send("rate_limit_create_topic=", @site_settings['rate_limit_create_topic'])
  SiteSetting.send("rate_limit_create_post=", @site_settings['rate_limit_create_post'])
  SiteSetting.send("max_topics_per_day=", @site_settings['max_topics_per_day'])
  SiteSetting.send("title_min_entropy=", @site_settings['title_min_entropy'])
  SiteSetting.send("body_min_entropy=", @site_settings['body_min_entropy'])
end

# Set temporary site settings needed for this rake task
def dc_set_temporary_site_settings
  SiteSetting.send("unique_posts_mins=", 0)
  SiteSetting.send("rate_limit_create_topic=", 0)
  SiteSetting.send("rate_limit_create_post=", 0)
  SiteSetting.send("max_topics_per_day=", 10000)
  SiteSetting.send("title_min_entropy=", 1)
  SiteSetting.send("body_min_entropy=", 1)
end

# Check if user exists
# For some really weird reason this method returns the opposite value
# So if it did find the user, the result is false
def dc_user_exists(name)
  User.where('username = ?', name).exists?
end

def dc_get_user_id(name)
  User.where('username = ?', name).first.id
end

def dc_get_user(name)
  User.where('username = ?', name).first
end

# Returns current unix time
def current_unix_time
  Time.now.to_i
end

def unix_to_human_time(unix_time)
  Time.at(unix_time).strftime("%d/%m/%Y %H:%M")
end

# Exit the script
def exit_script
  puts "\nScript will now exit\n".yellow
  exit
end

def phpbb_username_to_dc(name)
  # Create username from full name, only letters and numbers
  username = name.tr('^A-Za-z0-9', '').downcase
  # Maximum length of a Discourse username is 15 characters
  username = username[0,15]
end

# Add colors to class String
class String
  def red
    colorize(self, 31);
  end

  def green
    colorize(self, 32);
  end

  def yellow
    colorize(self, 33);
  end

  def blue
    colorize(self, 34);
  end

  def colorize(text, color_code)
    "\033[#{color_code}m#{text}\033[0m"
  end
end

# Calculate percentage
class Numeric
  def percent_of(n)
    self.to_f / n.to_f * 100.0
  end
end
