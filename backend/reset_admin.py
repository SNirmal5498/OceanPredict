from app import app, db, User
from werkzeug.security import generate_password_hash

with app.app_context():
    user = User.query.filter_by(email='admin@example.com').first()
    if user:
        user.password = generate_password_hash('password123')
        user.role = 'admin'
        user.status = 'active'
        print("Updated existing admin account.")
    else:
        user = User(
            name='Admin',
            email='admin@example.com',
            password=generate_password_hash('password123'),
            role='admin',
            status='active'
        )
        db.session.add(user)
        print("Created new admin account.")
    
    db.session.commit()