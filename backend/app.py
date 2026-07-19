import xarray as xr
import tempfile
import os
import pandas as pd
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, create_access_token
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config

app = Flask(__name__)
app.config.from_object(Config)

db = SQLAlchemy(app)
jwt = JWTManager(app)
CORS(app)


class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)


class Dataset(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    filename = db.Column(db.String(255), nullable=False)
    upload_date = db.Column(db.DateTime, server_default=db.func.now())
    total_records = db.Column(db.Integer, default=0)


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


@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()

    if User.query.filter_by(email=data['email']).first():
        return jsonify({'message': 'Email already registered'}), 400

    hashed_password = generate_password_hash(data['password'])
    new_user = User(name=data['name'], email=data['email'], password=hashed_password)
    db.session.add(new_user)
    db.session.commit()

    return jsonify({'message': 'User registered successfully'}), 201


@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    user = User.query.filter_by(email=data['email']).first()

    if not user or not check_password_hash(user.password, data['password']):
        return jsonify({'message': 'Invalid email or password'}), 401

    access_token = create_access_token(identity=str(user.id))
    return jsonify({'access_token': access_token, 'name': user.name}), 200


@app.route('/dashboard/stats', methods=['GET'])
def dashboard_stats():
    total_records = FloatData.query.count()
    active_floats = db.session.query(FloatData.float_id).distinct().count()

    avg_temp = db.session.query(db.func.avg(FloatData.temperature)).scalar()
    avg_salinity = db.session.query(db.func.avg(FloatData.salinity)).scalar()

    return jsonify({
        'total_records': total_records,
        'active_floats': active_floats,
        'avg_temperature': round(avg_temp, 2) if avg_temp else 0,
        'avg_salinity': round(avg_salinity, 2) if avg_salinity else 0,
    }), 200


@app.route('/seed-sample-data', methods=['POST'])
def seed_sample_data():
    dataset = Dataset(user_id=1, filename='sample_argo_data.csv', total_records=5)
    db.session.add(dataset)
    db.session.commit()

    sample_points = [
        {'float_id': 'F001', 'latitude': 12.4, 'longitude': 68.2, 'temperature': 18.5, 'salinity': 35.1, 'pressure': 500, 'cycle_number': 12},
        {'float_id': 'F002', 'latitude': 15.1, 'longitude': 70.3, 'temperature': 22.1, 'salinity': 34.8, 'pressure': 300, 'cycle_number': 8},
        {'float_id': 'F003', 'latitude': 9.8, 'longitude': 65.5, 'temperature': 16.2, 'salinity': 35.4, 'pressure': 700, 'cycle_number': 20},
        {'float_id': 'F004', 'latitude': 13.6, 'longitude': 72.1, 'temperature': 19.9, 'salinity': 35.0, 'pressure': 450, 'cycle_number': 15},
        {'float_id': 'F005', 'latitude': 11.2, 'longitude': 69.9, 'temperature': 20.4, 'salinity': 34.9, 'pressure': 550, 'cycle_number': 10},
    ]

    for point in sample_points:
        entry = FloatData(dataset_id=dataset.id, **point)
        db.session.add(entry)

    db.session.commit()
    return jsonify({'message': 'Sample data seeded successfully'}), 201

@app.route('/upload', methods=['POST'])
def upload_dataset():
    if 'file' not in request.files:
        return jsonify({'message': 'No file provided'}), 400

    file = request.files['file']

    with tempfile.NamedTemporaryFile(delete=False, suffix='.nc') as tmp:
        file.save(tmp.name)
        tmp_path = tmp.name

    try:
        ds = xr.open_dataset(tmp_path)

        latitudes = ds['LATITUDE'].values
        longitudes = ds['LONGITUDE'].values
        temperatures = ds['TEMP'].values
        salinities = ds['PSAL'].values
        pressures = ds['PRES'].values
        cycle_numbers = ds['CYCLE_NUMBER'].values
        platform_number = str(ds['PLATFORM_NUMBER'].values[0]).strip()

        ds.close()
    except KeyError as e:
        os.remove(tmp_path)
        return jsonify({'message': f'Missing expected variable in NetCDF file: {e}'}), 400

    dataset = Dataset(user_id=1, filename=file.filename, total_records=0)
    db.session.add(dataset)
    db.session.commit()

    records_added = 0
    n_profiles = len(latitudes)

    for p in range(n_profiles):
        # Handle both 1D (single level) and 2D (multi-level) temp/sal/pressure arrays
        if temperatures.ndim == 1:
            levels_temp = [temperatures[p]]
            levels_sal = [salinities[p]]
            levels_pres = [pressures[p]]
        else:
            levels_temp = temperatures[p]
            levels_sal = salinities[p]
            levels_pres = pressures[p]

        for level in range(len(levels_temp)):
            temp_val = levels_temp[level]
            sal_val = levels_sal[level]
            pres_val = levels_pres[level]

            # Skip missing/NaN readings (common in real ocean sensor data)
            if pd.isna(temp_val) or pd.isna(sal_val) or pd.isna(pres_val):
                continue

            entry = FloatData(
                dataset_id=dataset.id,
                float_id=platform_number,
                latitude=float(latitudes[p]),
                longitude=float(longitudes[p]),
                temperature=float(temp_val),
                salinity=float(sal_val),
                pressure=float(pres_val),
                cycle_number=int(cycle_numbers[p]),
            )
            db.session.add(entry)
            records_added += 1

    dataset.total_records = records_added
    db.session.commit()
    os.remove(tmp_path)

    return jsonify({
        'message': 'Upload successful',
        'records_added': records_added,
        'filename': file.filename,
    }), 201


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000, debug=True)