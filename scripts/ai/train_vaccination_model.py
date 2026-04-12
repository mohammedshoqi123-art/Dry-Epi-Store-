#!/usr/bin/env python3
"""
Vaccination Analysis Model Training Script
Trains a TensorFlow model for EPI vaccination coverage prediction.
Converts to TFLite for on-device inference.

Usage:
  python train_vaccination_model.py --data vaccination_data.csv --output epi_model.tflite
"""

import argparse
import os
import numpy as np
import pandas as pd

try:
    import tensorflow as tf
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import StandardScaler
except ImportError:
    print("Required packages: tensorflow scikit-learn pandas numpy")
    print("Install: pip install tensorflow scikit-learn pandas numpy")
    exit(1)


class VaccinationPredictor:
    """Neural network model for vaccination analysis predictions."""

    def __init__(self):
        self.model = self._build_model()
        self.scaler = StandardScaler()

    def _build_model(self):
        model = tf.keras.Sequential([
            tf.keras.layers.Dense(64, activation='relu', input_shape=(10,)),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(32, activation='relu'),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(16, activation='relu'),
            tf.keras.layers.Dense(5, activation='linear')
            # Outputs: coverage_rate, dropout_rate, wastage_rate, shortage_risk, risk_score
        ])

        model.compile(
            optimizer='adam',
            loss='mse',
            metrics=['mae']
        )

        return model

    def prepare_data(self, df):
        """Prepare features and labels from DataFrame."""
        feature_cols = [
            'total_submissions', 'submitted_count', 'rejected_count',
            'pending_count', 'coverage_rate_7d', 'dropout_rate_7d',
            'avg_daily_submissions', 'days_since_last_sync',
            'governorate_encoded', 'district_encoded'
        ]

        label_cols = [
            'target_coverage_rate', 'target_dropout_rate',
            'target_wastage_rate', 'target_shortage_risk', 'target_risk_score'
        ]

        # Generate synthetic data if columns don't exist
        for col in feature_cols:
            if col not in df.columns:
                df[col] = np.random.rand(len(df))

        for col in label_cols:
            if col not in df.columns:
                df[col] = np.random.rand(len(df)) * 0.5 + 0.25

        X = df[feature_cols].values.astype(np.float32)
        y = df[label_cols].values.astype(np.float32)

        return X, y

    def train(self, data_path, epochs=100, batch_size=32):
        """Train the model on CSV data."""
        print(f"Loading data from {data_path}...")
        df = pd.read_csv(data_path)

        X, y = self.prepare_data(df)

        # Split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        # Normalize
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)

        print(f"Training on {len(X_train)} samples, validating on {len(X_test)} samples")
        print(f"Input shape: {X_train_scaled.shape}, Output shape: {y_train.shape}")

        # Train
        history = self.model.fit(
            X_train_scaled, y_train,
            validation_data=(X_test_scaled, y_test),
            epochs=epochs,
            batch_size=batch_size,
            verbose=1,
            callbacks=[
                tf.keras.callbacks.EarlyStopping(
                    patience=10, restore_best_weights=True
                ),
                tf.keras.callbacks.ReduceLROnPlateau(
                    factor=0.5, patience=5
                ),
            ]
        )

        # Evaluate
        loss, mae = self.model.evaluate(X_test_scaled, y_test, verbose=0)
        print(f"\nTest Loss: {loss:.4f}, Test MAE: {mae:.4f}")

        return history

    def train_synthetic(self, n_samples=10000, epochs=50):
        """Train on synthetic data for bootstrapping."""
        print(f"Generating {n_samples} synthetic training samples...")

        np.random.seed(42)
        data = {
            'total_submissions': np.random.randint(0, 500, n_samples),
            'submitted_count': np.random.randint(0, 400, n_samples),
            'rejected_count': np.random.randint(0, 100, n_samples),
            'pending_count': np.random.randint(0, 50, n_samples),
            'coverage_rate_7d': np.random.rand(n_samples),
            'dropout_rate_7d': np.random.rand(n_samples) * 0.3,
            'avg_daily_submissions': np.random.rand(n_samples) * 50,
            'days_since_last_sync': np.random.randint(0, 30, n_samples),
            'governorate_encoded': np.random.rand(n_samples),
            'district_encoded': np.random.rand(n_samples),
        }

        # Derived labels (realistic relationships)
        coverage = data['submitted_count'] / np.maximum(data['total_submissions'], 1)
        dropout = data['pending_count'] / np.maximum(data['total_submissions'], 1)
        wastage = data['rejected_count'] / np.maximum(data['total_submissions'], 1)
        shortage_risk = 1 - coverage
        risk_score = dropout * 0.4 + (1 - coverage) * 0.3 + wastage * 0.3

        data['target_coverage_rate'] = coverage
        data['target_dropout_rate'] = dropout
        data['target_wastage_rate'] = wastage
        data['target_shortage_risk'] = shortage_risk
        data['target_risk_score'] = np.clip(risk_score, 0, 1)

        df = pd.DataFrame(data)

        # Save synthetic data
        synthetic_path = 'synthetic_vaccination_data.csv'
        df.to_csv(synthetic_path, index=False)
        print(f"Synthetic data saved to {synthetic_path}")

        return self.train(synthetic_path, epochs=epochs)

    def convert_to_tflite(self, output_path, quantize=True):
        """Convert trained model to TFLite format."""
        print(f"Converting to TFLite (quantize={quantize})...")

        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)

        if quantize:
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            converter.target_spec.supported_types = [tf.float16]

        tflite_model = converter.convert()

        with open(output_path, 'wb') as f:
            f.write(tflite_model)

        size_kb = os.path.getsize(output_path) / 1024
        print(f"TFLite model saved to {output_path} ({size_kb:.1f} KB)")

        # Save scaler parameters
        scaler_path = output_path.replace('.tflite', '_scaler.npz')
        np.savez(
            scaler_path,
            mean=self.scaler.mean_,
            scale=self.scaler.scale_,
        )
        print(f"Scaler parameters saved to {scaler_path}")

        return output_path

    def predict_sample(self, features):
        """Run inference on a single sample."""
        features_scaled = self.scaler.transform(
            np.array([features], dtype=np.float32)
        )
        prediction = self.model.predict(features_scaled, verbose=0)[0]
        return {
            'coverage_rate': float(prediction[0]),
            'dropout_rate': float(prediction[1]),
            'wastage_rate': float(prediction[2]),
            'shortage_risk': float(prediction[3]),
            'risk_score': float(np.clip(prediction[4], 0, 1)),
        }


def main():
    parser = argparse.ArgumentParser(
        description='Train EPI vaccination analysis model'
    )
    parser.add_argument(
        '--data', type=str, default=None,
        help='Path to training CSV data (uses synthetic if not provided)'
    )
    parser.add_argument(
        '--output', type=str, default='epi_analysis_model.tflite',
        help='Output TFLite model path'
    )
    parser.add_argument(
        '--epochs', type=int, default=100,
        help='Training epochs'
    )
    parser.add_argument(
        '--batch-size', type=int, default=32,
        help='Training batch size'
    )
    parser.add_argument(
        '--synthetic-samples', type=int, default=10000,
        help='Number of synthetic samples (when no data file)'
    )
    parser.add_argument(
        '--no-quantize', action='store_true',
        help='Disable TFLite quantization'
    )

    args = parser.parse_args()

    predictor = VaccinationPredictor()

    # Train
    if args.data and os.path.exists(args.data):
        predictor.train(args.data, epochs=args.epochs, batch_size=args.batch_size)
    else:
        print("No data file provided, using synthetic data for bootstrapping...")
        predictor.train_synthetic(n_samples=args.synthetic_samples, epochs=args.epochs)

    # Convert
    predictor.convert_to_tflite(args.output, quantize=not args.no_quantize)

    # Test prediction
    print("\n--- Test Prediction ---")
    sample = [100, 85, 5, 10, 0.85, 0.1, 15.0, 2, 0.5, 0.3]
    result = predictor.predict_sample(sample)
    for k, v in result.items():
        print(f"  {k}: {v:.4f}")


if __name__ == '__main__':
    main()
