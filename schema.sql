CREATE TABLE songs (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    lyrics TEXT NOT NULL
);
INSERT INTO songs (title, author, lyrics)
VALUES (
        'Example Title',
        'Example Author',
        'Example Lyrics'
    );