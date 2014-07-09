# [Obsolete]

The purpose of this repo was to import posts and users from phpBB forums into Discourse. This task is now better done using [the official solution from the Discourse team themselves](https://meta.discourse.org/t/phpbb-3-importer/17397).

This repo will stay up for posterity; the original readme is kept intact below.

@rikkit

---

# Note

I (@cfstras) don't have the time to work on this actively anymore. Since Discourse is still in early beta,
this importer might not even work anymore. If you want to take over the project, I'll give up this
repository to anyone who sends useful and sane pull requests. For more details and discussion, see
[this thread on Discourse Meta](http://meta.discourse.org/t/importing-phpbb-into-discourse/7956).

# What is this?

This rake task will import all threads and posts of a phpBB3 Forum into Discourse.

* post dates and authors are preserved
* user accounts are created from phpBB users, they have no login capability,
  but the mail addresses are set, so they can regain control and gravatar works, if they have one
* there is a test-mode which will just connect to mysql and read posts
* post bodies are sanitized:
  * youtube and soundcloud tags are removed (because discourse does oneboxing for them)
  * bbcode tags are cleaned up
  * newlines are converted to markdown syntax
  * `[code]` tags are converted to markdown syntax
  * CAPSLOCK and `\(^-^)/` symbol-only messages are prefixed with `<capslock>` and `<symbols>`

Use at your own risk! Please test on a dummy Discourse install first.

# Instructions

* Important: **disable** your e-mail configuration or you will spam users with hundreds of mails:

  Add this to your environment config:

  ```ruby
  config.action_mailer.delivery_method = :test
  config.action_mailer.smtp_settings = { address: "localhost", port: 1025 }
  ```
  Start mailcatcher to see when all mails have been sent:

  ```bash
  gem install mailcatcher && mailcatcher --http-ip 0.0.0.0
  ```

* Be sure to have at least one user in your discourse.
  If not, create one and set his username in `config/import_phpbb.yml`.

* Gemfile: add entry


  ```Gemfile
  gem 'mysql2', require: false
  gem 'ruby-bbcode-to-md', require: false
  ```

* Install header files for mysql, ex. on Debian: `sudo apt-get install libmysqlclient-dev`
* Install gems: `gem install mysql2` and `gem install ruby-bbcode-to-md`
* Edit `config/import_phpbb.yml`: insert database connection and discourse_admin username
* Place `config/import_phpbb.yml` in your `discourse/config` folder
* Place `lib/tasks/import_phpbb.rake` in your `discourse/lib/tasks` folder
* In case of multisite prepend next command with: `export RAILS_DB=<your database>`
* Now you need to add two columns to your PHPbb table. In the mysql console, run:
```mysql
ALTER TABLE phpbb_topics ADD COLUMN discourse_id INT NOT NULL DEFAULT '0';
ALTER TABLE phpbb_posts ADD COLUMN discourse_id INT NOT NULL DEFAULT '0';
```
* Finally, run `rake import:phpbb`
* If everything worked, reset your config and tell your people to reset their password on the new site.

# ToDo

* Add required tables automatically in the script

# Notes

If you find this helpful or can't get it to work, feel free to pop me a message!
