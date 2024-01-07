from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import create_engine
from azapi import AZlyrics

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = '???' #'postgresql+psycopg2://<db_user>:<db_password>@<db_host>:<db_port>/<db_name>'
# https://stackoverflow.com/questions/58921457/having-trouble-connecting-to-cloud-sql-postgresql-using-pythons-sqlalchemy
db = SQLAlchemy(app)
engine = create_engine(app.config['SQLALCHEMY_DATABASE_URI'])

class Song(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    author = db.Column(db.String(255), nullable=False)
    lyrics = db.Column(db.Text, nullable=False)

@app.route('/add_song', methods=['POST'])
def add_song():
    data = request.get_json()
    title = data['title']
    author = data['author']
    lyrics = fetch_lyrics_from_external_api(title, author)
    song = Song(title=title, author=author, lyrics=lyrics)
    db.session.add(song)
    db.session.commit()
    return jsonify({'message': 'Song added successfully!'})

@app.route('/get_songs', methods=['GET'])
def get_songs():
    songs = Song.query.all()
    song_list = [{'title': song.title, 'author': song.author} for song in songs]
    return jsonify({'songs': song_list})

@app.route('/get_lyrics/<int:song_id>', methods=['GET'])
def get_lyrics(song_id):
    song = Song.query.get(song_id)
    return jsonify({'title': song.title, 'author': song.author, 'lyrics': song.lyrics})

def fetch_lyrics_from_external_api(title, author):
    api = AZlyrics()
    api.artist = author
    api.title = title
    api.getLyrics(save=False)
    return api.lyrics

if __name__ == '__main__':
    app.run(debug=True)