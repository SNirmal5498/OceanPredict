from app import app, db
from sqlalchemy import text

with app.app_context():
    db.session.execute(text('ALTER TABLE "user" ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT \'user\';'))
    db.session.execute(text('ALTER TABLE "user" ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT \'active\';'))
    db.session.commit()
    print("Database columns added successfully!")