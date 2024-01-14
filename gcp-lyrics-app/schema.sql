CREATE TABLE IF NOT EXISTS song (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    lyrics TEXT NOT NULL
);
INSERT INTO song (title, author, lyrics)
SELECT 'Example Title',
    'Example Author',
    'Example Lyrics'
WHERE NOT EXISTS (
        SELECT title
        FROM song
        WHERE title = 'Example Title'
    );