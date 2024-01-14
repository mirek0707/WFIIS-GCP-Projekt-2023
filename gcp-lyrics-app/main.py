from flask import Flask, request, jsonify, send_file
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import create_engine, text
from azapi import AZlyrics

app = Flask(__name__)
# app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://oariyhyv:ogz5l586X7kNEkhnbpCY5SyyiSG_P1id@balarama.db.elephantsql.com/oariyhyv'
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql+psycopg2://postgres:postgres@/postgres?host=/cloudsql/gcp-lyrics-app:us-central1:song'

db = SQLAlchemy(app)
engine = create_engine(app.config['SQLALCHEMY_DATABASE_URI'])

with engine.begin() as conn:
    with open('schema.sql', 'r') as script_file:
        sql_script = script_file.read()
        result = conn.execute(text(sql_script)) 
        conn.commit()     

class Song(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)
    author = db.Column(db.String(255), nullable=False)
    lyrics = db.Column(db.Text, nullable=False)

@app.route('/')
def home():
    return send_file('index.html')

@app.route('/add-song', methods=['POST'])
def add_song():
    data = request.get_json()
    title = data['title']
    author = data['author']
    existing_song = Song.query.filter_by(title=title, author=author).first()
    if existing_song:
        return jsonify({'error': 'Song already exists in the database.'}), 400

    lyrics = fetch_lyrics_from_external_api(title, author)
    if lyrics:
        song = Song(title=title, author=author, lyrics=lyrics)
        db.session.add(song)
        db.session.commit()
        return jsonify({'message': 'Song added successfully!'})
    else:
        return jsonify({'error': "Lyrics not found!"}), 400 

@app.route('/get-songs', methods=['GET'])
def get_songs():
    songs = Song.query.all()
    song_list = [{'title': song.title, 'author': song.author, 'id': song.id} for song in songs]
    return jsonify({'songs': song_list})

@app.route('/get-lyrics/<int:song_id>', methods=['GET'])
def get_lyrics(song_id):
    song = Song.query.get(song_id)
    return jsonify({'title': song.title, 'author': song.author, 'lyrics': song.lyrics})

def fetch_lyrics_from_external_api(title, author):
    proxies = {
    'http': '79.110.194.117:8081',
    'https': '139.180.39.201:8080',
    }
    api = AZlyrics(accuracy=0.5,
                 proxies=proxies)
    api.artist = author
    api.title = title
    api.getLyrics(save=False)
    return api.lyrics

if __name__ == '__main__':
    # with open('schema.sql', 'r') as script_file:
    #     sql_script = script_file.read()
    #     engine.execute(sql_script)
    app.run(debug=True, host="0.0.0.0", port=int(8080))