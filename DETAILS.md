# Notes for converting phpBB to Discourse


## Getting all posts from phpBB

This query selects all posts, along with their user ids, topic ids, post ids, usernames and topic names.

    SELECT t.topic_id, t.topic_title,
    u.username, u.user_id,
    p.post_time, p.post_id,
    p.post_text
    FROM phpbb_posts p
    JOIN phpbb_topics t ON t.topic_id=p.topic_id
    JOIN phpbb_users u ON u.user_id=p.poster_id
    ORDER BY topic_id ASC, topic_title ASC, post_id ASC;

