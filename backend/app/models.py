# TODO: Define SQLAlchemy or other ORM models
# These will represent off-chain data stored in PostgreSQL.
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Message(Base):
    __tablename__ = 'messages'
    id = Column(Integer, primary_key=True)
    content = Column(String)
    like_count = Column(Integer, default=0)
    alert_count = Column(Integer, default=0)
    # ... other fields
