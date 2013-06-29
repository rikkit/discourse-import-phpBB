# Notes for converting phpBB to Discourse

## Getting data from phpBB

This query selects all posts, along with their user ids, topic ids, post ids, usernames and topic names.

   SELECT t.topic_id, t.topic_title,
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
      LIMIT #{offset.to_s},500;

This query is used for getting user info:

    SELECT * 
      FROM phpbb_users u
      JOIN phpbb_groups g ON g.group_id = u.group_id
      WHERE g.group_name != 'BOTS'
      ORDER BY u.user_id ASC
      LIMIT #{offset}, 50;
