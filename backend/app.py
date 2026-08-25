import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
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


@app.route('/analytics/summary', methods=['GET'])
def analytics_summary():
    temp_stats = db.session.query(
        db.func.avg(FloatData.temperature),
        db.func.min(FloatData.temperature),
        db.func.max(FloatData.temperature),
    ).first()

    sal_stats = db.session.query(
        db.func.avg(FloatData.salinity),
        db.func.min(FloatData.salinity),
        db.func.max(FloatData.salinity),
    ).first()

    pres_stats = db.session.query(
        db.func.avg(FloatData.pressure),
        db.func.max(FloatData.pressure),
    ).first()

    def safe_round(val):
        return round(val, 2) if val is not None else 0

    return jsonify({
        'temperature': {
            'avg': safe_round(temp_stats[0]),
            'min': safe_round(temp_stats[1]),
            'max': safe_round(temp_stats[2]),
        },
        'salinity': {
            'avg': safe_round(sal_stats[0]),
            'min': safe_round(sal_stats[1]),
            'max': safe_round(sal_stats[2]),
        },
        'pressure': {
            'avg': safe_round(pres_stats[0]),
            'max_depth': safe_round(pres_stats[1]),
        },
    }), 200


@app.route('/floats/locations', methods=['GET'])
def float_locations():
    # Get the most recent reading per float (distinct float_id, latest by id)
    subquery = db.session.query(
        FloatData.float_id,
        db.func.max(FloatData.id).label('max_id')
    ).group_by(FloatData.float_id).subquery()

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
        })

    return jsonify({'floats': result}), 200

@app.route('/floats/<float_id>/history', methods=['GET'])
def float_history(float_id):
    readings = FloatData.query.filter_by(float_id=float_id).order_by(FloatData.id).all()

    if not readings:
        return jsonify({'message': 'No data found for this float'}), 404

    history = []
    for r in readings:
        history.append({
            'cycle_number': r.cycle_number,
            'latitude': round(r.latitude, 2) if r.latitude else None,
            'longitude': round(r.longitude, 2) if r.longitude else None,
            'temperature': round(r.temperature, 2) if r.temperature else None,
            'salinity': round(r.salinity, 2) if r.salinity else None,
            'pressure': round(r.pressure, 2) if r.pressure else None,
        })

    latest = readings[-1]

    return jsonify({
        'float_id': float_id,
        'total_readings': len(readings),
        'latest': {
            'latitude': round(latest.latitude, 2) if latest.latitude else None,
            'longitude': round(latest.longitude, 2) if latest.longitude else None,
            'cycle_number': latest.cycle_number,
        },
        'history': history,
    }), 200

@app.route('/floats/ids', methods=['GET'])
def float_ids():
    ids = db.session.query(FloatData.float_id).distinct().all()
    return jsonify({'float_ids': [i[0] for i in ids]}), 200


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
        raw_platform = ds['PLATFORM_NUMBER'].values[0]
        if isinstance(raw_platform, bytes):
          platform_number = raw_platform.decode('utf-8').strip()
        else:
          platform_number = str(raw_platform).strip()

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

@app.route('/api/predictions', methods=['POST'])
def predict():
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

    query = FloatData.query
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

    test_size = max(1, round(n * 0.2))
    train_size = n - test_size
    if train_size < 2:
        train_size = n - 1
        test_size = 1

    X_train, X_test = X[:train_size], X[train_size:]
    y_train, y_test = y[:train_size], y[train_size:]

    def make_model():
        if model_type == 'linear_regression':
            return LinearRegression()
        return RandomForestRegressor(n_estimators=100, random_state=42)

    eval_model = make_model()
    eval_model.fit(X_train, y_train)
    y_pred_test = eval_model.predict(X_test)

    mae = float(mean_absolute_error(y_test, y_pred_test))
    rmse = float(np.sqrt(mean_squared_error(y_test, y_pred_test)))
    r2 = float(r2_score(y_test, y_pred_test)) if len(y_test) > 1 else None

    feature_importance = None
    if model_type == 'random_forest':
        importances = eval_model.feature_importances_
        names = ['Cycle Number', 'Pressure', 'Latitude', 'Longitude']
        total = sum(importances) or 1
        feature_importance = {
            names[i]: round(float(importances[i]) / total * 100, 1) for i in range(len(names))
        }

    # Final model retrained on ALL available real data for the actual forecast.
    final_model = make_model()
    final_model.fit(X, y)

    last_cycle = int(X[-1][0])
    last_pressure, last_lat, last_lon = X[-1][1], X[-1][2], X[-1][3]

    forecast = []
    for step in range(1, horizon + 1):
        future_cycle = last_cycle + step
        # Future pressure/lat/long are unknown, so we hold them at the last
        # observed real values — a documented simplification, not fake data.
        future_X = np.array([[future_cycle, last_pressure, last_lat, last_lon]])
        pred_val = float(final_model.predict(future_X)[0])
        forecast.append({'step': step, 'cycle': future_cycle, 'predicted_value': round(pred_val, 2)})

    return jsonify({
        'model': model_type,
        'target': target,
        'float_id': float_id,
        'horizon': horizon,
        'latest_actual_value': round(float(y[-1]), 2),
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

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000, debug=True)