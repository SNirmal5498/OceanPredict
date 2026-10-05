import os
import tempfile
from functools import wraps

import numpy as np
import pandas as pd
import xarray as xr
from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_jwt_extended import (
    JWTManager,
    create_access_token,
    get_jwt_identity,
    jwt_required,
)
from flask_sqlalchemy import SQLAlchemy
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from werkzeug.security import check_password_hash, generate_password_hash

from config import Config

# Initialize App & Extensions once
app = Flask(__name__)
app.config.from_object(Config)

# Configure JWT explicit token locations & header formatting
app.config["JWT_TOKEN_LOCATION"] = ["headers"]
app.config["JWT_HEADER_NAME"] = "Authorization"
app.config["JWT_HEADER_TYPE"] = "Bearer"

db = SQLAlchemy(app)
jwt = JWTManager(app)
CORS(app, resources={r"/*": {"origins": "*"}})


# ==================================================
# DATABASE MODELS
# ==================================================

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), nullable=False, default='user')
    status = db.Column(db.String(20), nullable=False, default='active')


class Dataset(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    filename = db.Column(db.String(255), nullable=False)
    upload_date = db.Column(db.DateTime, server_default=db.func.now())
    total_records = db.Column(db.Integer, default=0)
    file_size = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    metadata_json = db.Column(db.Text, nullable=True)
    user = db.relationship('User', backref=db.backref('datasets', lazy=True))


class FloatData(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    dataset_id = db.Column(db.Integer, db.ForeignKey('dataset.id'), nullable=False)
    float_id = db.Column(db.String(50))
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    temperature = db.Column(db.Float)
    salinity = db.Column(db.Float)
    pressure = db.Column(db.Float)
    cycle_number = db.Column(db.Integer)
    timestamp = db.Column(db.DateTime)


class SystemLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    event = db.Column(db.String(255), nullable=False)
    user_email = db.Column(db.String(120), nullable=True)
    timestamp = db.Column(db.DateTime, server_default=db.func.now())


# ==================================================
# HELPERS & DECORATORS
# ==================================================

import json

def get_active_dataset(user_id=None):
    ds = Dataset.query.filter_by(is_active=True).order_by(Dataset.id.desc()).first()
    if ds:
        return ds
    if user_id is not None:
        ds = Dataset.query.filter_by(user_id=user_id).order_by(Dataset.id.desc()).first()
        if ds:
            ds.is_active = True
            db.session.commit()
            return ds
    ds = Dataset.query.order_by(Dataset.id.desc()).first()
    if ds:
        ds.is_active = True
        db.session.commit()
    return ds

def admin_required():
    def decorator(fn):
        @wraps(fn)
        @jwt_required(optional=True)
        def wrapper(*args, **kwargs):
            if request.method == 'OPTIONS':
                return jsonify({'status': 'ok'}), 200
            user_id = get_jwt_identity()
            if not user_id:
                return jsonify({'message': 'Missing or invalid token'}), 401
            user = User.query.get(int(user_id))
            if not user or user.role.lower() != 'admin':
                return jsonify({'message': 'Admin privilege required.'}), 403
            return fn(*args, **kwargs)
        return wrapper
    return decorator


def log_event(event_description, email=None):
    log = SystemLog(event=event_description, user_email=email)
    db.session.add(log)
    db.session.commit()


# ==================================================
# AUTHENTICATION ENDPOINTS
# ==================================================

@app.route('/register', methods=['POST', 'OPTIONS'])
def register():
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200

    try:
        data = request.get_json() or {}
        if not data.get('email') or not data.get('password'):
            return jsonify({'message': 'Email and password required'}), 400

        if User.query.filter_by(email=data['email']).first():
            return jsonify({'message': 'Email already registered'}), 400

        hashed_password = generate_password_hash(data['password'])
        # Public registration always creates standard 'user' role
        role = 'user'
        new_user = User(
            name=data.get('name', 'User'),
            email=data['email'],
            password=hashed_password,
            role=role
        )
        db.session.add(new_user)
        db.session.commit()

        log_event(f"User registered ({role})", data['email'])
        return jsonify({'message': 'User registered successfully'}), 201
    except Exception as e:
        print(f"Register Exception: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/login', methods=['POST', 'OPTIONS'])
def login():
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200

    try:
        data = request.get_json() or {}
        email = data.get('email')
        password = data.get('password')

        if not email or not password:
            return jsonify({'message': 'Missing email or password'}), 400

        user = User.query.filter_by(email=email).first()

        if user and check_password_hash(user.password, password):
            # Pass user.id directly as identity string
            access_token = create_access_token(identity=str(user.id))
            log_event("User logged in", user.email)
            return jsonify({
                'token': access_token,
                'user': {
                    'id': user.id,
                    'name': user.name,
                    'email': user.email,
                    'role': user.role
                }
            }), 200

        return jsonify({'message': 'Invalid email or password'}), 401

    except Exception as e:
        print(f"Login Exception: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/auth/profile', methods=['GET', 'PUT', 'OPTIONS'])
@jwt_required(optional=True)
def auth_profile():
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200

    user_id = get_jwt_identity()
    if not user_id:
        return jsonify({'message': 'Missing or invalid token'}), 401

    user = User.query.get(int(user_id))
    if not user:
        return jsonify({'message': 'User not found'}), 404

    if request.method == 'GET':
        return jsonify({
            'id': user.id,
            'name': user.name,
            'email': user.email,
            'role': user.role,
            'status': user.status
        }), 200

    if request.method == 'PUT':
        data = request.get_json() or {}
        name = data.get('name')
        email = data.get('email')

        if name and name.strip():
            user.name = name.strip()
        if email and email.strip():
            new_email = email.strip().lower()
            if new_email != user.email:
                existing = User.query.filter_by(email=new_email).first()
                if existing and existing.id != user.id:
                    return jsonify({'message': 'Email already registered'}), 400
                user.email = new_email

        db.session.commit()
        log_event(f"Profile updated for user {user.id}", user.email)
        return jsonify({
            'message': 'Profile updated successfully',
            'user': {
                'id': user.id,
                'name': user.name,
                'email': user.email,
                'role': user.role,
                'status': user.status
            }
        }), 200


# ==================================================
# ADMIN PANEL ENDPOINTS
# ==================================================

@app.route('/api/admin/stats', methods=['GET', 'OPTIONS'])
@admin_required()
def admin_stats():
    total_users = User.query.count()
    total_datasets = Dataset.query.count()
    total_records = FloatData.query.count()
    active_users = User.query.filter_by(status='active').count()

    return jsonify({
        'totalUsers': total_users,
        'totalDatasets': total_datasets,
        'totalRecords': total_records,
        'activeUsers': active_users,
    }), 200


@app.route('/api/admin/users', methods=['GET', 'OPTIONS'])
@admin_required()
def admin_users():
    users = User.query.all()
    result = [{
        'id': u.id,
        'name': u.name,
        'email': u.email,
        'role': u.role,
        'status': u.status,
    } for u in users]
    return jsonify(result), 200


@app.route('/api/admin/users/<int:user_id>/role', methods=['PUT', 'OPTIONS'])
@admin_required()
def admin_update_role(user_id):
    data = request.get_json() or {}
    new_role = data.get('role')
    
    if new_role not in ['user', 'admin']:
        return jsonify({'message': 'Invalid role specified'}), 400

    target_user = User.query.get(user_id)
    if not target_user:
        return jsonify({'message': 'User not found'}), 404

    target_user.role = new_role
    db.session.commit()

    current_admin_id = get_jwt_identity()
    admin_user = User.query.get(int(current_admin_id))
    log_event(f"Role updated to {new_role} for {target_user.email}", admin_user.email if admin_user else None)

    return jsonify({'message': 'Role updated successfully'}), 200


@app.route('/api/admin/datasets', methods=['GET', 'OPTIONS'])
@admin_required()
def admin_datasets():
    datasets = Dataset.query.all()
    result = [{
        'id': d.id,
        'name': d.filename,
        'uploadedBy': d.user.email if d.user else 'Unknown',
        'records': d.total_records,
        'status': 'Processed',
    } for d in datasets]
    return jsonify(result), 200


@app.route('/api/admin/system/status', methods=['GET', 'OPTIONS'])
@admin_required()
def admin_system_status():
    return jsonify({
        'Backend': 'Online',
        'Database': 'Connected',
        'API': 'Online',
        'ML Service': 'Available',
    }), 200


@app.route('/api/admin/system/logs', methods=['GET', 'OPTIONS'])
@admin_required()
def admin_system_logs():
    logs = SystemLog.query.order_by(SystemLog.timestamp.desc()).limit(20).all()
    result = [{
        'id': l.id,
        'event': l.event,
        'user': l.user_email or 'System',
        'timestamp': l.timestamp.strftime('%Y-%m-%d %H:%M:%S') if l.timestamp else '',
    } for l in logs]
    return jsonify(result), 200


# ==================================================
# DATASET MANAGEMENT & ACTIVE DATASET ENDPOINTS
# ==================================================

@app.route('/api/datasets', methods=['GET'])
@jwt_required()
def get_datasets_list():
    user_id = int(get_jwt_identity())
    datasets = Dataset.query.filter_by(user_id=user_id).order_by(Dataset.upload_date.desc()).all()
    res = []
    for d in datasets:
        meta = json.loads(d.metadata_json) if d.metadata_json else {}
        res.append({
            'id': d.id,
            'filename': d.filename,
            'upload_date': d.upload_date.strftime('%Y-%m-%d %H:%M:%S') if d.upload_date else '',
            'total_records': d.total_records,
            'file_size': d.file_size or 0,
            'is_active': bool(d.is_active),
            'metadata': meta,
        })
    return jsonify(res), 200


@app.route('/api/datasets/<int:dataset_id>/activate', methods=['POST'])
@jwt_required()
def activate_dataset(dataset_id):
    user_id = int(get_jwt_identity())
    target = Dataset.query.filter_by(id=dataset_id, user_id=user_id).first()
    if not target:
        return jsonify({'message': 'Dataset not found or access denied'}), 404
    Dataset.query.filter_by(user_id=user_id).update({Dataset.is_active: False})
    target.is_active = True
    db.session.commit()
    user = User.query.get(user_id)
    log_event(f"Activated dataset {target.filename}", email=user.email if user else None)
    return jsonify({'message': f'Dataset {target.filename} is now active'}), 200


@app.route('/api/datasets/active', methods=['GET'])
@jwt_required()
def get_active_dataset_info():
    user_id = int(get_jwt_identity())
    ds = get_active_dataset(user_id=user_id)
    if not ds:
        return jsonify({'active': False, 'message': 'No active dataset available'}), 200
    meta = json.loads(ds.metadata_json) if ds.metadata_json else {}
    return jsonify({
        'active': True,
        'id': ds.id,
        'filename': ds.filename,
        'upload_date': ds.upload_date.strftime('%Y-%m-%d %H:%M:%S') if ds.upload_date else '',
        'total_records': ds.total_records,
        'file_size': ds.file_size or 0,
        'is_active': True,
        'metadata': meta,
    }), 200


# ==================================================
# APPLICATION MODULES & DATA ENDPOINTS
# ==================================================

@app.route('/dashboard/stats', methods=['GET'])
@jwt_required()
def dashboard_stats():
    user_id = int(get_jwt_identity())
    active_ds = get_active_dataset(user_id=user_id)
    if not active_ds:
        return jsonify({
            'active': False,
            'total_records': 0,
            'active_floats': 0,
            'avg_temperature': None,
            'avg_salinity': None,
            'dataset_name': None,
        }), 200

    query = FloatData.query.filter_by(dataset_id=active_ds.id)
    total_records = query.count()
    active_floats = db.session.query(FloatData.float_id).filter_by(dataset_id=active_ds.id).distinct().count()

    avg_temp = db.session.query(db.func.avg(FloatData.temperature)).filter(
        FloatData.dataset_id == active_ds.id, FloatData.temperature.isnot(None)
    ).scalar()
    avg_salinity = db.session.query(db.func.avg(FloatData.salinity)).filter(
        FloatData.dataset_id == active_ds.id, FloatData.salinity.isnot(None)
    ).scalar()

    meta = json.loads(active_ds.metadata_json) if active_ds.metadata_json else {}

    return jsonify({
        'active': True,
        'dataset_id': active_ds.id,
        'dataset_name': active_ds.filename,
        'file_size': active_ds.file_size or 0,
        'upload_date': active_ds.upload_date.strftime('%Y-%m-%d %H:%M:%S') if active_ds.upload_date else '',
        'total_records': total_records,
        'active_floats': active_floats,
        'avg_temperature': round(avg_temp, 2) if avg_temp is not None else None,
        'avg_salinity': round(avg_salinity, 2) if avg_salinity is not None else None,
        'metadata': meta,
    }), 200


@app.route('/analytics/summary', methods=['GET'])
@jwt_required()
def analytics_summary():
    user_id = int(get_jwt_identity())
    active_ds = get_active_dataset(user_id=user_id)
    if not active_ds:
        return jsonify({
            'active': False,
            'temperature': {'avg': None, 'min': None, 'max': None},
            'salinity': {'avg': None, 'min': None, 'max': None},
            'pressure': {'avg': None, 'max_depth': None},
        }), 200

    temp_stats = db.session.query(
        db.func.avg(FloatData.temperature),
        db.func.min(FloatData.temperature),
        db.func.max(FloatData.temperature),
    ).filter(FloatData.dataset_id == active_ds.id, FloatData.temperature.isnot(None)).first()

    sal_stats = db.session.query(
        db.func.avg(FloatData.salinity),
        db.func.min(FloatData.salinity),
        db.func.max(FloatData.salinity),
    ).filter(FloatData.dataset_id == active_ds.id, FloatData.salinity.isnot(None)).first()

    pres_stats = db.session.query(
        db.func.avg(FloatData.pressure),
        db.func.max(FloatData.pressure),
    ).filter(FloatData.dataset_id == active_ds.id, FloatData.pressure.isnot(None)).first()

    def safe_round(val):
        return round(val, 2) if val is not None else None

    return jsonify({
        'active': True,
        'temperature': {
            'avg': safe_round(temp_stats[0]) if temp_stats else None,
            'min': safe_round(temp_stats[1]) if temp_stats else None,
            'max': safe_round(temp_stats[2]) if temp_stats else None,
        },
        'salinity': {
            'avg': safe_round(sal_stats[0]) if sal_stats else None,
            'min': safe_round(sal_stats[1]) if sal_stats else None,
            'max': safe_round(sal_stats[2]) if sal_stats else None,
        },
        'pressure': {
            'avg': safe_round(pres_stats[0]) if pres_stats else None,
            'max_depth': safe_round(pres_stats[1]) if pres_stats else None,
        },
    }), 200


@app.route('/floats/locations', methods=['GET'])
@jwt_required()
def float_locations():
    user_id = int(get_jwt_identity())
    active_ds = get_active_dataset(user_id=user_id)
    if not active_ds:
        return jsonify({'floats': []}), 200

    subquery = db.session.query(
        FloatData.float_id,
        db.func.max(FloatData.id).label('max_id')
    ).filter(FloatData.dataset_id == active_ds.id).group_by(FloatData.float_id).subquery()

    latest_readings = db.session.query(FloatData).join(
        subquery, FloatData.id == subquery.c.max_id
    ).all()

    result = []
    for reading in latest_readings:
        result.append({
            'float_id': reading.float_id,
            'latitude': round(reading.latitude, 2) if reading.latitude else None,
            'longitude': round(reading.longitude, 2) if reading.longitude else None,
            'temperature': round(reading.temperature, 2) if reading.temperature else None,
            'salinity': round(reading.salinity, 2) if reading.salinity else None,
            'pressure': round(reading.pressure, 2) if reading.pressure else None,
            'timestamp': reading.timestamp.strftime('%Y-%m-%d %H:%M:%S') if reading.timestamp else None,
            'cycle_number': reading.cycle_number,
        })

    return jsonify({'floats': result}), 200


@app.route('/floats/<float_id>/history', methods=['GET'])
@jwt_required()
def float_history(float_id):
    user_id = int(get_jwt_identity())
    active_ds = get_active_dataset(user_id=user_id)
    if not active_ds:
        return jsonify({'message': 'No active dataset available'}), 404

    if float_id.lower() == 'all':
        readings = FloatData.query.filter_by(dataset_id=active_ds.id).order_by(FloatData.id).all()
    else:
        readings = FloatData.query.filter_by(dataset_id=active_ds.id, float_id=float_id).order_by(FloatData.id).all()

    if not readings:
        return jsonify({'message': 'No data found for this float in active dataset'}), 404

    history = []
    for r in readings:
        history.append({
            'cycle_number': r.cycle_number,
            'latitude': round(r.latitude, 2) if r.latitude else None,
            'longitude': round(r.longitude, 2) if r.longitude else None,
            'temperature': round(r.temperature, 2) if r.temperature else None,
            'salinity': round(r.salinity, 2) if r.salinity else None,
            'pressure': round(r.pressure, 2) if r.pressure else None,
            'timestamp': r.timestamp.strftime('%Y-%m-%d %H:%M:%S') if r.timestamp else None,
        })

    latest = readings[-1]

    return jsonify({
        'float_id': float_id,
        'total_readings': len(readings),
        'latest': {
            'latitude': round(latest.latitude, 2) if latest.latitude else None,
            'longitude': round(latest.longitude, 2) if latest.longitude else None,
            'cycle_number': latest.cycle_number,
            'timestamp': latest.timestamp.strftime('%Y-%m-%d %H:%M:%S') if latest.timestamp else None,
        },
        'history': history,
    }), 200


@app.route('/floats/ids', methods=['GET'])
@jwt_required()
def float_ids():
    user_id = int(get_jwt_identity())
    active_ds = get_active_dataset(user_id=user_id)
    if not active_ds:
        return jsonify({'float_ids': []}), 200
    ids = db.session.query(FloatData.float_id).filter_by(dataset_id=active_ds.id).distinct().all()
    return jsonify({'float_ids': [i[0] for i in ids]}), 200


@app.route('/api/reports/data', methods=['GET'])
@jwt_required()
def reports_data():
    user_id = int(get_jwt_identity())
    active_ds = get_active_dataset(user_id=user_id)
    if not active_ds:
        return jsonify({
            'active': False,
            'message': 'No active dataset available',
            'records': [],
            'timestamp_available': False,
            'min_timestamp': None,
            'max_timestamp': None,
            'active_floats': 0,
            'total_records': 0,
            'float_ids': [],
        }), 200

    query = FloatData.query.filter_by(dataset_id=active_ds.id).order_by(FloatData.id)
    readings = query.all()

    float_ids_list = [i[0] for i in db.session.query(FloatData.float_id).filter_by(dataset_id=active_ds.id).distinct().all()]

    ts_list = [r.timestamp for r in readings if r.timestamp is not None]
    timestamp_available = len(ts_list) > 0
    min_ts_str = min(ts_list).strftime('%Y-%m-%d %H:%M:%S') if timestamp_available else None
    max_ts_str = max(ts_list).strftime('%Y-%m-%d %H:%M:%S') if timestamp_available else None

    records = []
    for r in readings:
        records.append({
            'id': r.id,
            'float_id': r.float_id,
            'latitude': round(r.latitude, 4) if r.latitude is not None else None,
            'longitude': round(r.longitude, 4) if r.longitude is not None else None,
            'temperature': round(r.temperature, 2) if r.temperature is not None else None,
            'salinity': round(r.salinity, 2) if r.salinity is not None else None,
            'pressure': round(r.pressure, 2) if r.pressure is not None else None,
            'cycle_number': r.cycle_number,
            'timestamp': r.timestamp.strftime('%Y-%m-%d %H:%M:%S') if r.timestamp else None,
        })

    meta = json.loads(active_ds.metadata_json) if active_ds.metadata_json else {}

    return jsonify({
        'active': True,
        'dataset_id': active_ds.id,
        'dataset_name': active_ds.filename,
        'upload_date': active_ds.upload_date.strftime('%Y-%m-%d %H:%M:%S') if active_ds.upload_date else '',
        'total_records': len(readings),
        'active_floats': len(float_ids_list),
        'float_ids': float_ids_list,
        'timestamp_available': timestamp_available,
        'min_timestamp': min_ts_str,
        'max_timestamp': max_ts_str,
        'records': records,
        'metadata': meta,
    }), 200


@app.route('/seed-sample-data', methods=['POST'])
@jwt_required()
def seed_sample_data():
    user_id = int(get_jwt_identity())
    from datetime import datetime, timedelta
    # Deactivate existing datasets for this user
    Dataset.query.filter_by(user_id=user_id).update({Dataset.is_active: False})

    sample_meta = {
        'validation': {
            'required_columns': 'Passed',
            'missing_values': 'Passed',
            'duplicate_check': 'Passed',
            'invalid_records': 'Passed',
            'quality_flags': 'Passed',
        },
        'cleaning': {
            'status': 'Completed',
            'duplicates_removed': 0,
            'missing_temp': 0,
            'missing_salinity': 0,
            'missing_pressure': 0,
            'missing_latitude': 0,
            'missing_longitude': 0,
            'missing_timestamp': 0,
            'missing_cycle': 0,
            'total_missing': 0,
            'rows_removed': 0,
            'rows_retained': 5,
            'flagged_for_review': 0,
        },
        'summary': {
            'number_of_floats': 5,
            'date_range': '2026-01-01 to 2026-01-05',
            'temp_min': 16.2,
            'temp_max': 22.1,
            'sal_min': 34.8,
            'sal_max': 35.4,
            'pres_max': 700.0,
            'timestamp_available': True,
            'cycle_available': True,
        }
    }

    dataset = Dataset(
        user_id=user_id,
        filename='sample_argo_data.csv',
        total_records=5,
        file_size=2048,
        is_active=True,
        metadata_json=json.dumps(sample_meta)
    )
    db.session.add(dataset)
    db.session.commit()

    sample_points = []
    # F001 multi-cycle profile (Cycles 1..12)
    for c in range(1, 13):
        sample_points.append({
            'float_id': 'F001',
            'latitude': 12.4 + (c * 0.05),
            'longitude': 68.2 + (c * 0.04),
            'temperature': round(18.5 - (c * 0.12), 2),
            'salinity': round(35.10 + (c * 0.03), 2),
            'pressure': 500,
            'cycle_number': c,
            'timestamp': datetime(2026, 1, c, 0, 0, 0),
        })
    # F002 multi-cycle profile (Cycles 1..10)
    for c in range(1, 11):
        sample_points.append({
            'float_id': 'F002',
            'latitude': 15.1 + (c * 0.04),
            'longitude': 70.3 + (c * 0.03),
            'temperature': round(22.10 - (c * 0.15), 2),
            'salinity': round(34.80 + (c * 0.02), 2),
            'pressure': 300,
            'cycle_number': c,
            'timestamp': datetime(2026, 1, c, 0, 0, 0),
        })
    # F003 multi-cycle profile (Cycles 1..8)
    for c in range(1, 9):
        sample_points.append({
            'float_id': 'F003',
            'latitude': 9.8 + (c * 0.03),
            'longitude': 65.5 + (c * 0.05),
            'temperature': round(16.20 + (c * 0.10), 2),
            'salinity': round(35.40 - (c * 0.03), 2),
            'pressure': 700,
            'cycle_number': c,
            'timestamp': datetime(2026, 1, c, 0, 0, 0),
        })

    for point in sample_points:
        entry = FloatData(dataset_id=dataset.id, **point)
        db.session.add(entry)

    db.session.commit()
    user = User.query.get(user_id)
    log_event("Seeded sample dataset with multi-cycle float trajectories", email=user.email if user else None)
    return jsonify({'message': 'Sample data seeded successfully'}), 201


@app.route('/upload', methods=['POST'])
@jwt_required()
def upload_dataset():
    user_id = int(get_jwt_identity())
    if 'file' not in request.files:
        return jsonify({'message': 'No file provided'}), 400

    file = request.files['file']
    filename = file.filename or 'dataset'
    ext = filename.split('.')[-1].lower()

    if ext not in ['csv', 'nc']:
        return jsonify({'message': 'Unsupported file format. Only CSV and NetCDF (.nc) are supported.'}), 400

    with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{ext}') as tmp:
        file.save(tmp.name)
        tmp_path = tmp.name

    file_size = os.path.getsize(tmp_path)
    raw_records = []

    missing_temp = 0
    missing_sal = 0
    missing_pres = 0
    missing_lat = 0
    missing_lon = 0
    missing_timestamp = 0
    missing_cycle = 0

    timestamp_available = False
    cycle_available = False

    try:
        if ext == 'csv':
            df = pd.read_csv(tmp_path)
            # Find column names case-insensitively
            col_map = {}
            for col in df.columns:
                col_lower = str(col).strip().lower()
                col_map[col_lower] = col

            def find_col(candidates):
                for cand in candidates:
                    if cand in col_map:
                        return col_map[cand]
                return None

            float_col = find_col(['float_id', 'platform_number', 'platform', 'float', 'id', 'wmo', 'platform_code'])
            lat_col = find_col(['latitude', 'lat'])
            lon_col = find_col(['longitude', 'lon', 'lng', 'long'])
            temp_col = find_col(['temperature', 'temp', 'sea_water_temperature'])
            sal_col = find_col(['salinity', 'psal', 'sal', 'sea_water_salinity'])
            pres_col = find_col(['pressure', 'pres', 'depth', 'sea_water_pressure'])
            time_col = find_col(['timestamp', 'date', 'time', 'datetime', 'juld'])
            cycle_col = find_col(['cycle_number', 'cycle', 'cycle_no'])

            if not (lat_col or temp_col or sal_col):
                os.remove(tmp_path)
                return jsonify({'message': 'CSV does not contain recognizable oceanographic columns (Latitude, Temperature, Salinity)'}), 400

            for idx, row in df.iterrows():
                f_id = str(row[float_col]).strip() if float_col and not pd.isna(row[float_col]) else 'F001'
                
                lat_val = float(row[lat_col]) if lat_col and not pd.isna(row[lat_col]) else None
                lon_val = float(row[lon_col]) if lon_col and not pd.isna(row[lon_col]) else None
                temp_val = float(row[temp_col]) if temp_col and not pd.isna(row[temp_col]) else None
                sal_val = float(row[sal_col]) if sal_col and not pd.isna(row[sal_col]) else None
                pres_val = float(row[pres_col]) if pres_col and not pd.isna(row[pres_col]) else None
                cycle_val = int(row[cycle_col]) if cycle_col and not pd.isna(row[cycle_col]) else 1

                ts_val = None
                if time_col and not pd.isna(row[time_col]):
                    try:
                        ts_val = pd.to_datetime(row[time_col])
                        timestamp_available = True
                    except Exception:
                        pass

                if cycle_col and not pd.isna(row[cycle_col]):
                    cycle_available = True

                raw_records.append({
                    'float_id': f_id,
                    'latitude': lat_val,
                    'longitude': lon_val,
                    'temperature': temp_val,
                    'salinity': sal_val,
                    'pressure': pres_val,
                    'cycle_number': cycle_val,
                    'timestamp': ts_val,
                })

        elif ext == 'nc':
            ds = xr.open_dataset(tmp_path)
            latitudes = ds['LATITUDE'].values if 'LATITUDE' in ds else np.array([0.0])
            longitudes = ds['LONGITUDE'].values if 'LONGITUDE' in ds else np.array([0.0])
            temperatures = ds['TEMP'].values if 'TEMP' in ds else np.array([])
            salinities = ds['PSAL'].values if 'PSAL' in ds else np.array([])
            pressures = ds['PRES'].values if 'PRES' in ds else np.array([])
            cycle_numbers = ds['CYCLE_NUMBER'].values if 'CYCLE_NUMBER' in ds else np.array([1]*len(latitudes))
            
            raw_platform = 'UNKNOWN'
            if 'PLATFORM_NUMBER' in ds:
                p_val = ds['PLATFORM_NUMBER'].values
                if len(p_val) > 0:
                    raw_platform = p_val[0].decode('utf-8').strip() if isinstance(p_val[0], bytes) else str(p_val[0]).strip()

            ds.close()

            if len(temperatures) > 0:
                n_profiles = len(latitudes)
                for p in range(n_profiles):
                    if temperatures.ndim == 1:
                        levels_temp = [temperatures[p]]
                        levels_sal = [salinities[p]] if len(salinities) > p else [None]
                        levels_pres = [pressures[p]] if len(pressures) > p else [None]
                    else:
                        levels_temp = temperatures[p]
                        levels_sal = salinities[p]
                        levels_pres = pressures[p]

                    for level in range(len(levels_temp)):
                        t_v = float(levels_temp[level]) if not pd.isna(levels_temp[level]) else None
                        s_v = float(levels_sal[level]) if not pd.isna(levels_sal[level]) else None
                        p_v = float(levels_pres[level]) if not pd.isna(levels_pres[level]) else None
                        
                        lat_v = float(latitudes[p]) if not pd.isna(latitudes[p]) else None
                        lon_v = float(longitudes[p]) if not pd.isna(longitudes[p]) else None
                        c_v = int(cycle_numbers[p]) if not pd.isna(cycle_numbers[p]) else 1

                        raw_records.append({
                            'float_id': raw_platform,
                            'latitude': lat_v,
                            'longitude': lon_v,
                            'temperature': t_v,
                            'salinity': s_v,
                            'pressure': p_v,
                            'cycle_number': c_v,
                            'timestamp': None,
                        })

    except Exception as e:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        return jsonify({'message': f'Error reading dataset file: {str(e)}'}), 400

    if os.path.exists(tmp_path):
        os.remove(tmp_path)

    # Perform Validation & Quality Flags Analysis
    total_raw_rows = len(raw_records)

    # Missing counts
    for r in raw_records:
        if r['temperature'] is None: missing_temp += 1
        if r['salinity'] is None: missing_sal += 1
        if r['pressure'] is None: missing_pres += 1
        if r['latitude'] is None: missing_lat += 1
        if r['longitude'] is None: missing_lon += 1
        if r['timestamp'] is None: missing_timestamp += 1
        if r['cycle_number'] is None: missing_cycle += 1

    total_missing = missing_temp + missing_sal + missing_pres + missing_lat + missing_lon

    # Data Quality Flags
    flagged_for_review = 0
    valid_records = []
    
    for r in raw_records:
        # Exclude completely broken rows (missing temp/sal/pres or lat/lon)
        if r['latitude'] is None or r['longitude'] is None or r['temperature'] is None or r['salinity'] is None or r['pressure'] is None:
            continue

        # Check scientific bounds for quality flagging
        is_flagged = False
        if r['temperature'] < -2.5 or r['temperature'] > 40.0: is_flagged = True
        if r['salinity'] < 0.0 or r['salinity'] > 50.0: is_flagged = True
        if r['pressure'] < 0.0 or r['pressure'] > 11000.0: is_flagged = True
        if r['latitude'] < -90.0 or r['latitude'] > 90.0: is_flagged = True
        if r['longitude'] < -180.0 or r['longitude'] > 180.0: is_flagged = True

        if is_flagged:
            flagged_for_review += 1

        valid_records.append(r)

    # Duplicate Detection
    seen_keys = set()
    deduped_records = []
    duplicates_count = 0

    for r in valid_records:
        key = (r['float_id'], r['cycle_number'], r['latitude'], r['longitude'], r['pressure'])
        if key in seen_keys:
            duplicates_count += 1
        else:
            seen_keys.add(key)
            deduped_records.append(r)

    rows_removed = total_raw_rows - len(deduped_records)
    rows_retained = len(deduped_records)

    # Validation Checks
    req_columns_check = 'Passed' if len(raw_records) > 0 else 'Failed'
    missing_check = 'Warning' if total_missing > 0 else 'Passed'
    duplicate_check = 'Passed' if duplicates_count == 0 else 'Warning'
    invalid_check = 'Warning' if flagged_for_review > 0 else 'Passed'
    quality_check = 'Warning' if flagged_for_review > 0 else 'Passed'

    # Cleaning Status
    cleaning_status = 'Completed'
    if duplicates_count > 0 or total_missing > 0 or flagged_for_review > 0:
        cleaning_status = 'Completed with Warnings'
    if rows_retained == 0:
        cleaning_status = 'Failed'

    # Temperature, Salinity, Pressure Ranges
    temps = [r['temperature'] for r in deduped_records if r['temperature'] is not None]
    sals = [r['salinity'] for r in deduped_records if r['salinity'] is not None]
    press = [r['pressure'] for r in deduped_records if r['pressure'] is not None]

    temp_min = round(min(temps), 2) if temps else None
    temp_max = round(max(temps), 2) if temps else None
    sal_min = round(min(sals), 2) if sals else None
    sal_max = round(max(sals), 2) if sals else None
    pres_max = round(max(press), 2) if press else None

    distinct_floats = len(set(r['float_id'] for r in deduped_records))

    meta = {
        'validation': {
            'required_columns': req_columns_check,
            'missing_values': missing_check,
            'duplicate_check': duplicate_check,
            'invalid_records': invalid_check,
            'quality_flags': quality_check,
        },
        'cleaning': {
            'status': cleaning_status,
            'duplicates_removed': duplicates_count,
            'missing_temp': missing_temp,
            'missing_salinity': missing_sal,
            'missing_pressure': missing_pres,
            'missing_latitude': missing_lat,
            'missing_longitude': missing_lon,
            'missing_timestamp': missing_timestamp,
            'missing_cycle': missing_cycle,
            'total_missing': total_missing,
            'rows_removed': rows_removed,
            'rows_retained': rows_retained,
            'flagged_for_review': flagged_for_review,
        },
        'summary': {
            'number_of_floats': distinct_floats,
            'date_range': 'Timestamp unavailable' if not timestamp_available else 'Available',
            'temp_min': temp_min,
            'temp_max': temp_max,
            'sal_min': sal_min,
            'sal_max': sal_max,
            'pres_max': pres_max,
            'timestamp_available': timestamp_available,
            'cycle_available': cycle_available,
        }
    }

    # Deactivate existing datasets for this user so newly uploaded dataset becomes Active
    Dataset.query.filter_by(user_id=user_id).update({Dataset.is_active: False})

    dataset = Dataset(
        user_id=user_id,
        filename=filename,
        total_records=rows_retained,
        file_size=file_size,
        is_active=True,
        metadata_json=json.dumps(meta)
    )
    db.session.add(dataset)
    db.session.commit()

    # Bulk insert FloatData
    for r in deduped_records:
        entry = FloatData(
            dataset_id=dataset.id,
            float_id=r['float_id'],
            latitude=r['latitude'],
            longitude=r['longitude'],
            temperature=r['temperature'],
            salinity=r['salinity'],
            pressure=r['pressure'],
            cycle_number=r['cycle_number'],
            timestamp=r['timestamp'],
        )
        db.session.add(entry)

    db.session.commit()

    user = User.query.get(user_id)
    log_event(f"Uploaded & activated dataset {filename}", email=user.email if user else None)
    return jsonify({
        'message': 'Upload successful',
        'dataset_id': dataset.id,
        'filename': filename,
        'records_added': rows_retained,
        'file_size': file_size,
        'is_active': True,
        'metadata': meta,
    }), 201


@app.route('/api/predictions', methods=['POST'])
@jwt_required()
def predict():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    model_type = data.get('model')
    target = data.get('target')
    float_id = data.get('float_id')
    horizon = data.get('horizon', 5)

    if model_type not in ('linear_regression', 'random_forest'):
        return jsonify({'message': 'Invalid model type'}), 400
    if target not in ('temperature', 'salinity'):
        return jsonify({'message': 'Invalid prediction target'}), 400
    try:
        horizon = int(horizon)
        if horizon < 1 or horizon > 50:
            raise ValueError
    except (TypeError, ValueError):
        return jsonify({'message': 'Invalid forecast horizon'}), 400

    active_ds = get_active_dataset(user_id=user_id)
    if not active_ds:
        return jsonify({'message': 'No active dataset available for prediction'}), 400

    query = FloatData.query.filter_by(dataset_id=active_ds.id)
    if float_id and float_id != 'all':
        query = query.filter_by(float_id=float_id)
    rows = query.order_by(FloatData.cycle_number.asc(), FloatData.id.asc()).all()

    feature_rows = []
    targets = []
    for r in rows:
        target_val = r.temperature if target == 'temperature' else r.salinity
        if (target_val is None or r.pressure is None or r.latitude is None
                or r.longitude is None or r.cycle_number is None):
            continue
        feature_rows.append([r.cycle_number, r.pressure, r.latitude, r.longitude])
        targets.append(target_val)

    n = len(targets)
    MIN_REQUIRED = 5
    if n < MIN_REQUIRED:
        return jsonify({
            'message': 'Insufficient historical data for prediction.',
            'available_records': n,
            'required_minimum': MIN_REQUIRED,
        }), 400

    X = np.array(feature_rows, dtype=float)
    y = np.array(targets, dtype=float)

    # Chronological Train / Test Split (Time-based, no future observation leakage)
    test_size = max(2, round(n * 0.2)) if n >= 6 else (2 if n >= 4 else 1)
    train_size = n - test_size
    if train_size < 2:
        train_size = n - 1
        test_size = 1

    X_train, X_test = X[:train_size], X[train_size:]
    y_train, y_test = y[:train_size], y[train_size:]

    if model_type == 'linear_regression':
        eval_model = LinearRegression()
        eval_model.fit(X_train, y_train)
        y_pred_test = eval_model.predict(X_test)
    else:
        # Trend-adjusted Random Forest for out-of-sample time-series forecasting
        lr_trend_eval = LinearRegression().fit(X_train[:, :1], y_train)
        res_train = y_train - lr_trend_eval.predict(X_train[:, :1])
        rf_eval = RandomForestRegressor(n_estimators=100, random_state=42)
        rf_eval.fit(X_train, res_train)
        y_pred_test = lr_trend_eval.predict(X_test[:, :1]) + rf_eval.predict(X_test)

    mae = float(mean_absolute_error(y_test, y_pred_test))
    rmse = float(np.sqrt(mean_squared_error(y_test, y_pred_test)))
    
    if len(y_test) > 1:
        try:
            raw_r2 = r2_score(y_test, y_pred_test)
            r2 = None if (np.isnan(raw_r2) or np.isinf(raw_r2)) else float(raw_r2)
        except Exception:
            r2 = None
    else:
        r2 = None

    names = ['Cycle Number', 'Pressure', 'Latitude', 'Longitude']
    feature_importance = None

    if float_id and float_id != 'all':
        last_cycle = int(X[-1][0])
        last_pressure, last_lat, last_lon = X[-1][1], X[-1][2], X[-1][3]
        latest_actual = round(float(y[-1]), 2)
    else:
        last_cycle = int(np.max(X[:, 0]))
        last_pressure = float(np.mean(X[:, 1]))
        last_lat = float(np.mean(X[:, 2]))
        last_lon = float(np.mean(X[:, 3]))
        latest_actual = round(float(np.mean(y[-5:])), 2) if len(y) >= 5 else round(float(y[-1]), 2)

    if model_type == 'linear_regression':
        final_model = LinearRegression()
        final_model.fit(X, y)
        importances = np.abs(final_model.coef_)
        total = float(np.sum(importances)) or 1.0
        feature_importance = {
            names[i]: round(float(importances[i]) / total * 100, 1) for i in range(len(names))
        }
        def predict_future(f_cycle, f_pres, f_lat, f_lon):
            return float(final_model.predict([[f_cycle, f_pres, f_lat, f_lon]])[0])
    else:
        final_model = RandomForestRegressor(n_estimators=100, random_state=42)
        final_model.fit(X, y)
        importances = final_model.feature_importances_
        total = float(np.sum(importances)) or 1.0
        feature_importance = {
            names[i]: round(float(importances[i]) / total * 100, 1) for i in range(len(names))
        }
        lr_trend_final = LinearRegression().fit(X[:, :1], y)
        step_slope = float(lr_trend_final.coef_[0]) if len(lr_trend_final.coef_) > 0 else 0.0
        base_pred = float(final_model.predict([[last_cycle, last_pressure, last_lat, last_lon]])[0])

        def predict_future(f_cycle, f_pres, f_lat, f_lon):
            step_offset = f_cycle - last_cycle
            return base_pred + (step_slope * step_offset)

    forecast = []
    for step in range(1, horizon + 1):
        future_cycle = last_cycle + step
        pred_val = predict_future(future_cycle, last_pressure, last_lat, last_lon)
        forecast.append({'step': step, 'cycle': future_cycle, 'predicted_value': round(pred_val, 2)})

    historical_series = []
    if float_id and float_id != 'all':
        cycle_groups = {}
        for r in rows:
            c = r.cycle_number
            val = r.temperature if target == 'temperature' else r.salinity
            if c is not None and val is not None:
                cycle_groups.setdefault(c, []).append(float(val))
        sorted_cycles = sorted(cycle_groups.keys())
        for c in sorted_cycles:
            vals = cycle_groups[c]
            avg_val = round(sum(vals) / len(vals), 2)
            historical_series.append({'cycle': c, 'value': avg_val})

    return jsonify({
        'model': model_type,
        'target': target,
        'float_id': float_id,
        'horizon': horizon,
        'latest_actual_value': latest_actual,
        'historical_series': historical_series,
        'forecast': forecast,
        'metrics': {
            'train_samples': train_size,
            'test_samples': test_size,
            'mae': round(mae, 2),
            'rmse': round(rmse, 2),
            'r2': round(r2, 2) if r2 is not None else None,
        },
        'feature_importance': feature_importance,
        'features_used': ['Cycle Number', 'Pressure', 'Latitude', 'Longitude'],
    }), 200


# ==================================================
# APP INITIALIZATION & DEFAULT SEEDING
# ==================================================

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        from sqlalchemy import text
        try:
            db.session.execute(text('ALTER TABLE dataset ADD COLUMN IF NOT EXISTS file_size INTEGER DEFAULT 0;'))
            db.session.execute(text('ALTER TABLE dataset ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;'))
            db.session.execute(text('ALTER TABLE dataset ADD COLUMN IF NOT EXISTS metadata_json TEXT;'))
            db.session.commit()
        except Exception as e:
            print("Database migration check note:", e)

        # Create a default admin user if one doesn't exist
        if not User.query.filter_by(email='admin@example.com').first():
            admin_user = User(
                name='Admin',
                email='admin@example.com',
                password=generate_password_hash('password123'),
                role='admin',
                status='active'
            )
            db.session.add(admin_user)
            db.session.commit()
            print("Default admin user created: admin@example.com / password123")

    app.run(host='127.0.0.1', port=5000, debug=True)