from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine, Column, Integer, String, Text
from sqlalchemy.ext.declarative import declarative_base
import smtplib, ssl
from email.mime.text import MIMEText

Base = declarative_base()

class Song(Base):
    __tablename__ = 'song'
    id = Column(Integer, primary_key=True)
    title = Column(String(255), nullable=False)
    author = Column(String(255), nullable=False)
    lyrics = Column(Text, nullable=False)

def get_engine():
    return create_engine(
        "postgresql+psycopg2://postgres:postgres@/postgres?host=/cloudsql/gcp-lyrics-app:us-central1:song"
    )

def get_record_count():
    engine = get_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        count = session.query(Song).count()
        return count
    finally:
        session.close()

@functions_framework.http
def send_email(request):
    record_count = get_record_count()

    sender = "gcpprojekt@gmail.com"
    receiver = "kolodziejm@student.agh.edu.pl"
    password = "vhbm byss rrun nlcs"

    message = MIMEText(f"The GCP Lyrics App project database contains {record_count} records.")

    message["From"] = sender
    message["To"] = receiver
    message["Subject"] = "Report on the GCP Lyrics App Database"
    try:
        with smtplib.SMTP_SSL(
            host="smtp.gmail.com", port=465, context=ssl.create_default_context()
        ) as server:
            server.login(sender, password)

            server.sendmail(
                from_addr=sender,
                to_addrs=receiver,
                msg=message.as_string(),
            )
        return f"Email sent successfully!"
    except Exception as e:
        return str(e)