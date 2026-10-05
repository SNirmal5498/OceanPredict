import unittest
import json
from app import app, db, User

class AdminAuthTestCase(unittest.TestCase):
    def setUp(self):
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        self.app = app.test_client()
        with app.app_context():
            db.create_all()
            # Create admin
            self.app.post('/register', json={
                'name': 'Admin User',
                'email': 'admin@test.com',
                'password': 'password123'
            })
            admin_user = User.query.filter_by(email='admin@test.com').first()
            admin_user.role = 'admin'
            db.session.commit()

            # Create normal user
            self.app.post('/register', json={
                'name': 'Normal User',
                'email': 'user@test.com',
                'password': 'password123'
            })

            # Obtain tokens
            admin_res = self.app.post('/login', json={'email': 'admin@test.com', 'password': 'password123'})
            self.admin_token = admin_res.get_json()['token']

            user_res = self.app.post('/login', json={'email': 'user@test.com', 'password': 'password123'})
            self.user_token = user_res.get_json()['token']

    def tearDown(self):
        with app.app_context():
            db.session.remove()
            db.drop_all()

    def test_registration_role_tampering_prevented(self):
        # Attempt to register with role=admin
        res = self.app.post('/register', json={
            'name': 'Hacker',
            'email': 'hacker@test.com',
            'password': 'password123',
            'role': 'admin'
        })
        self.assertEqual(res.status_code, 201)
        with app.app_context():
            user = User.query.filter_by(email='hacker@test.com').first()
            self.assertEqual(user.role, 'user')  # Must be forced to 'user'

    def test_normal_user_admin_api_denied_403(self):
        headers = {'Authorization': f'Bearer {self.user_token}'}
        endpoints = [
            ('/api/admin/stats', 'GET'),
            ('/api/admin/users', 'GET'),
            ('/api/admin/datasets', 'GET'),
            ('/api/admin/system/status', 'GET'),
            ('/api/admin/system/logs', 'GET'),
        ]
        for ep, method in endpoints:
            with self.subTest(endpoint=ep):
                res = self.app.open(ep, method=method, headers=headers)
                self.assertEqual(res.status_code, 403, f"Endpoint {ep} should return 403 for normal user")
                data = res.get_json()
                self.assertIn('message', data)

    def test_admin_user_admin_api_allowed_200(self):
        headers = {'Authorization': f'Bearer {self.admin_token}'}
        endpoints = [
            ('/api/admin/stats', 'GET'),
            ('/api/admin/users', 'GET'),
            ('/api/admin/datasets', 'GET'),
            ('/api/admin/system/status', 'GET'),
            ('/api/admin/system/logs', 'GET'),
        ]
        for ep, method in endpoints:
            with self.subTest(endpoint=ep):
                res = self.app.open(ep, method=method, headers=headers)
                self.assertEqual(res.status_code, 200, f"Endpoint {ep} should return 200 for admin user")

    def test_options_preflight_allowed(self):
        res = self.app.options('/api/admin/stats')
        self.assertEqual(res.status_code, 200)

if __name__ == '__main__':
    unittest.main()
