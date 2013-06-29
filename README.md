# What is it?

This rake task will import all threads and posts of a phpBB Forum into Discourse.

* post dates and authors are preserved
* user accounts are created from phpBB users, they have no login capability,
  but the mail addresses are set, so they can regain control and gravatar works, if they have one
* there is a test-mode which will just connect to mysql and read posts
* post bodies are sanitized, image-tags are replaced, etc.

Use at your own risk! Please test on a dummy Discourse install first.

# Instructions

* Gemfile: add entry
  `gem 'mysql2', require: false`
* Install dev files for mysql, ex. on Debian: `sudo apt-get install libmysqlclient-dev`
* Install gem: `gem install mysql2`
* Edit `config/import_phpbb.yml`
* Place `config/import_phpbb.yml` in your `discourse/config` folder
* Place `lib/tasks/import_phpbb.rake` in your `discourse/lib/tasks` folder
* In case of multisite prepend next command with: `export RAILS_DB=<your database>`
* Run `rake import:phpbb`

# Todo

* Implement more sanitization
* Detect previously imported posts so migration can be done incrementally
