# What is it?

This rake task will import all Threads and Posts of a phpBB Forum into Discourse.

* It will preserve post and comment dates
* It will create new user accounts for each imported user using their email address and the same user as in phpBB
* It has a test mode. When enables no changes to the Discourse database will be made

Use at your own risk! Please test on a dummy Discourse install first.

# Instructions

* Gemfile: add mysql2
* Edit `config/import_phpbb.yml`
* Place `config/import_phpbb.yml` in your `config` folder
* Place `lib/tasks/import_phpbb.rake` in your `lib/tasks` folder
* In case of multisite prepend next command with: `export RAILS_DB=<your database>`
* Run `rake import:import_phpbb`

# Todo

* Implement.
* Import new posts/comments after last import
