from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.preprocessing import LabelEncoder
from sklearn.base import clone
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline
import pandas as pd
import numpy as np
from typing import Dict, List, Tuple
import joblib
from .constants import TACTICAL_CATEGORIES

class TacticalPredictor:
    def __init__(self):
        self.model = None
        self.feature_names = None
        self.scaler = None
        self._initialize_tactics_mapping()
    
    def _initialize_tactics_mapping(self):
        """Initialize mappings for tactics and their categories."""
        self.tactics_to_category = {}
        for category, tactics in TACTICAL_CATEGORIES.items():
            for tactic in tactics.keys():
                self.tactics_to_category[tactic] = category
    
    def prepare_features(self, game_data: pd.DataFrame) -> pd.DataFrame:
        """Prepare features for training/prediction."""
        print("\nPreparing features...")
        features = game_data.copy()
        
        # Debug information
        print(f"\nInitial columns: {features.columns.tolist()}")
        print(f"Initial shape: {features.shape}")
        print("\nInitial data types:")
        print(features.dtypes)
        
        # Remove probability columns for training
        prob_columns = [col for col in features.columns if col.startswith('prob_')]
        features = features.drop(columns=prob_columns)
        
        # Drop unnecessary columns
        columns_to_drop = [
            'description', 'tactical_probabilities', 'primary_tactic',
            'batting_team', 'count', 'pitcher_id', 'batter_id'
        ]
        features = features.drop(columns=[c for c in columns_to_drop if c in features.columns])
        
        # Process runners dictionary if it exists
        if 'runners' in features.columns:
            if isinstance(features['runners'].iloc[0], dict):
                features['num_runners'] = features['runners'].apply(lambda x: x.get('num_runners', 0))
                features['scoring_position'] = features['runners'].apply(lambda x: x.get('scoring_position', False))
            features = features.drop('runners', axis=1)
        
        # Convert boolean columns to int
        bool_columns = features.select_dtypes(include=['bool']).columns
        for col in bool_columns:
            features[col] = features[col].astype(int)
        
        # Convert categorical to dummies if not already
        if 'half_inning' in features.columns:
            features = pd.get_dummies(features, columns=['half_inning'])
        if 'result' in features.columns:
            features = pd.get_dummies(features, columns=['result'])
        
        # Convert all remaining columns to numeric
        for col in features.columns:
            if features[col].dtype != 'int64':
                features[col] = pd.to_numeric(features[col], errors='coerce').fillna(0)
        
        # Ensure all expected features are present
        if self.feature_names is not None:
            for col in self.feature_names:
                if col not in features.columns:
                    features[col] = 0
            features = features[self.feature_names]
        
        print("\nFinal columns:", features.columns.tolist())
        print("Final shape:", features.shape)
        print("\nFinal data types:")
        print(features.dtypes)
        
        # Check for any remaining non-numeric
        non_numeric = features.select_dtypes(exclude=['int64', 'float64']).columns
        if len(non_numeric) > 0:
            print("\nWarning: Converting remaining non-numeric columns to int:", non_numeric.tolist())
            for col in non_numeric:
                features[col] = features[col].astype(int)
        
        # Replace infinite values with 0
        features = features.replace([np.inf, -np.inf], 0)
        
        return features

    def train(self, training_data: pd.DataFrame, optimize: bool = True):
        """Train the tactical prediction model."""
        print("\nStarting model training...")
        
        try:
            X = self.prepare_features(training_data)
            y = training_data['primary_tactic']
            
            # Remove 'other' class
            mask = y != 'other'
            X = X[mask]
            y = y[mask]
            
            # Store feature names
            self.feature_names = X.columns.tolist()
            
            # Calculate custom weights
            custom_weights = self._calculate_custom_weights(y)
            
            print("\nTraining data summary:")
            print(f"Features shape: {X.shape}")
            print(f"Target classes: {y.unique().tolist()}")
            print("\nClass distribution:")
            print(y.value_counts())
            
            # Split data
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42, stratify=y
            )
            
            if optimize:
                print("\nPerforming grid search...")
                param_grid = {
                    'n_estimators': [100, 200],
                    'max_depth': [8, 10],
                    'min_samples_leaf': [30, 50],
                    'min_samples_split': [30, 50],
                    'max_features': ['sqrt', 'log2'],
                    'ccp_alpha': [0.01, 0.02]
                }
                
                scoring = {
                    'accuracy': 'accuracy',
                    'f1_weighted': 'f1_weighted',
                    'precision_weighted': 'precision_weighted',
                    'recall_weighted': 'recall_weighted'
                }
                
                grid_search = GridSearchCV(
                    RandomForestClassifier(
                        class_weight=custom_weights,
                        random_state=42
                    ),
                    param_grid,
                    cv=5,
                    scoring=scoring,
                    refit='f1_weighted',
                    n_jobs=-1,
                    verbose=2
                )
                
                grid_search.fit(X_train, y_train)
                self.model = grid_search.best_estimator_
                
                print("\nGrid Search Results:")
                for metric in scoring.keys():
                    scores = grid_search.cv_results_[f'mean_test_{metric}']
                    stds = grid_search.cv_results_[f'std_test_{metric}']
                    best_idx = scores.argmax()
                    print(f"\nBest {metric}: {scores[best_idx]:.3f} (+/- {stds[best_idx]*2:.3f})")
                    print(f"Parameters: {grid_search.cv_results_['params'][best_idx]}")
                
                print(f"\nBest overall parameters: {grid_search.best_params_}")
            else:
                print("\nTraining with default parameters...")
                self.model = RandomForestClassifier(
                    n_estimators=200,
                    max_depth=8,
                    min_samples_leaf=30,
                    min_samples_split=30,
                    max_features='sqrt',
                    ccp_alpha=0.01,
                    class_weight=custom_weights,
                    random_state=42
                )
                self.model.fit(X_train, y_train)
            
            # Detailed evaluation
            print("\nDetailed Model Evaluation:")
            self._evaluate_model(X_test, y_test)
            self._analyze_feature_importance()
            self._analyze_prediction_confidence(X_test, y_test)
            self._perform_cross_validation(X, y)
            
        except Exception as e:
            print(f"\nError during training: {str(e)}")
            raise

    def predict_proba(self, game_state: pd.DataFrame) -> Dict[str, Dict[str, float]]:
        """Predict probabilities for each tactic, grouped by category."""
        features = self.prepare_features(game_state)
        probabilities = self.model.predict_proba(features)[0]
        
        # Organize probabilities by category
        tactics_by_category = {category: {} for category in TACTICAL_CATEGORIES.keys()}
        
        for tactic, prob in zip(self.model.classes_, probabilities):
            if prob >= 0.05:  # Only include probabilities >= 5%
                category = self.tactics_to_category.get(tactic, 'OTHER')
                tactics_by_category[category][tactic] = round(prob * 100, 2)
        
        # Sort within each category
        for category in tactics_by_category:
            tactics_by_category[category] = dict(
                sorted(
                    tactics_by_category[category].items(),
                    key=lambda x: x[1],
                    reverse=True
                )
            )
        
        return tactics_by_category

    def analyze_situation(self, game_state: pd.DataFrame) -> Dict:
        """Analyze game situation and provide detailed tactical analysis."""
        try:
            tactical_probs = self.predict_proba(game_state)
            context = self._analyze_context(game_state)
            
            # Get top 3 most likely tactics overall
            all_probs = {
                tactic: prob 
                for category in tactical_probs.values() 
                for tactic, prob in category.items()
            }
            top_tactics = dict(
                sorted(all_probs.items(), key=lambda x: x[1], reverse=True)[:3]
            )
            
            # Generate recommendations
            recommendations = []
            for tactic, prob in top_tactics.items():
                rec = {
                    'tactic': tactic,
                    'probability': prob,
                    'reasoning': self._get_recommendation_reasoning(tactic, context),
                    'specific_actions': self._get_specific_actions(tactic, context)
                }
                recommendations.append(rec)
            
            return {
                'tactical_probabilities': tactical_probs,
                'top_tactics': top_tactics,
                'context_analysis': context,
                'recommendations': recommendations
            }
        except Exception as e:
            print(f"Error in analyze_situation: {str(e)}")
            raise

    def _analyze_context(self, game_state: pd.DataFrame) -> Dict:
        """Analyze game context factors."""
        context = {}
        
        # Game situation
        context['game_situation'] = {
            'inning': int(game_state['inning'].iloc[0]),
            'outs': int(game_state['outs'].iloc[0]),
            'score_diff': int(game_state['score_diff'].iloc[0]),
            'pressure_index': round(float(game_state['pressure_index'].iloc[0]), 2)
        }
        
        # Base/Runner situation
        context['runner_situation'] = {
            'runners': int(game_state['num_runners'].iloc[0]) if 'num_runners' in game_state.columns else 0,
            'scoring_position': bool(game_state['scoring_position'].iloc[0]) if 'scoring_position' in game_state.columns else False
        }
        
        return context

    def _evaluate_model(self, X_test: pd.DataFrame, y_test: pd.Series):
        """Evaluate model performance."""
        y_pred = self.model.predict(X_test)
        
        print("\nModel Evaluation:")
        print("-" * 50)
        print(f"Accuracy: {accuracy_score(y_test, y_pred):.3f}")
        print("\nClassification Report:")
        print(classification_report(y_test, y_pred))
        
        # Confusion matrix
        cm = confusion_matrix(y_test, y_pred)
        print("\nConfusion Matrix:")
        print(cm)

    def _analyze_feature_importance(self):
        """Analyze and print feature importance."""
        if not hasattr(self.model, 'feature_importances_'):
            print("Model doesn't support feature importance analysis")
            return
            
        importances = pd.DataFrame({
            'feature': self.feature_names,
            'importance': self.model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        print("\nTop Feature Contributions:")
        print("-" * 50)
        for _, row in importances.head(10).iterrows():
            print(f"{row['feature']:<30} {row['importance']*100:>6.2f}%")

    def _get_recommendation_reasoning(self, tactic: str, context: Dict) -> str:
        """Generate reasoning for a tactical recommendation."""
        game_situation = context['game_situation']
        runner_situation = context['runner_situation']
        
        reasons = []
        
        if game_situation['inning'] >= 7:
            reasons.append("Late game situation")
        if game_situation['pressure_index'] > 1.5:
            reasons.append("High pressure situation")
        if runner_situation['scoring_position']:
            reasons.append("Runners in scoring position")
        
        if abs(game_situation['score_diff']) <= 2:
            reasons.append("Close game")
        elif game_situation['score_diff'] > 0:
            reasons.append("Leading by multiple runs")
        else:
            reasons.append("Trailing by multiple runs")
        
        for category, tactics in TACTICAL_CATEGORIES.items():
            if tactic in tactics:
                if category == 'OFFENSIVE' and runner_situation['scoring_position']:
                    reasons.append("Good opportunity for run scoring")
                elif category == 'DEFENSIVE' and game_situation['pressure_index'] > 1.5:
                    reasons.append("Critical defensive situation")
        
        return " | ".join(reasons) if reasons else "Based on general game situation"

    def _get_specific_actions(self, tactic: str, context: Dict) -> List[str]:
        """Get specific actions for a tactic based on context."""
        for category, tactics in TACTICAL_CATEGORIES.items():
            if tactic in tactics:
                return tactics[tactic]
        return []

    def save_model(self, filename: str = 'models/tactical_predictor.joblib'):
        """Save the trained model and feature names."""
        model_data = {
            'model': self.model,
            'feature_names': self.feature_names
        }
        joblib.dump(model_data, filename)
        print(f"\nModel saved to {filename}")

    def load_model(self, filename: str = 'models/tactical_predictor.joblib'):
        """Load a trained model and feature names."""
        try:
            model_data = joblib.load(filename)
            self.model = model_data['model']
            self.feature_names = model_data['feature_names']
            print(f"\nModel loaded from {filename}")
            print(f"Available tactics: {self.model.classes_}")
        except Exception as e:
            print(f"\nError loading model: {str(e)}")
            raise


    def _calculate_custom_weights(self, y: pd.Series) -> Dict[str, float]:
        """Calculate custom class weights based on distribution."""
        class_dist = y.value_counts()
        n_samples = len(y)
        n_classes = len(class_dist)
        
        # Base weights
        weights = {
            class_label: n_samples / (n_classes * count)
            for class_label, count in class_dist.items()
        }
        
        # Boost underrepresented classes
        median_count = class_dist.median()
        for class_label, count in class_dist.items():
            if count < median_count * 0.2:  # Significantly underrepresented
                weights[class_label] *= 1.5
        
        return weights

    def _analyze_prediction_confidence(self, X: pd.DataFrame, y: pd.Series = None):
        """Analyze prediction confidence distributions."""
        probas = self.model.predict_proba(X)
        max_probas = np.max(probas, axis=1)
        
        print("\nPrediction Confidence Analysis:")
        print("-" * 50)
        print(f"Mean confidence: {max_probas.mean():.3f}")
        print(f"Median confidence: {np.median(max_probas):.3f}")
        print(f"Std deviation: {max_probas.std():.3f}")
        
        # Confidence thresholds analysis
        thresholds = [0.5, 0.7, 0.9]
        for threshold in thresholds:
            pct_above = (max_probas >= threshold).mean() * 100
            print(f"Predictions with confidence >= {threshold}: {pct_above:.1f}%")
        
        if y is not None:
            # Class-wise confidence analysis
            print("\nConfidence by Class:")
            for i, class_label in enumerate(self.model.classes_):
                mask = y == class_label
                if any(mask):
                    class_probs = probas[mask][:, i]
                    print(f"\n{class_label}:")
                    print(f"  Mean confidence: {class_probs.mean():.3f}")
                    print(f"  Median confidence: {np.median(class_probs):.3f}")
                    print(f"  Std deviation: {class_probs.std():.3f}")

    def _perform_cross_validation(self, X: pd.DataFrame, y: pd.Series, cv: int = 5):
        """Perform detailed cross-validation analysis."""
        print("\nCross-validation Analysis:")
        print("-" * 50)
        
        # Initialize metrics
        metrics = {
            'accuracy': [],
            'weighted_f1': [],
            'class_f1': {class_label: [] for class_label in np.unique(y)}
        }
        
        # Create folds
        from sklearn.model_selection import StratifiedKFold
        skf = StratifiedKFold(n_splits=cv, shuffle=True, random_state=42)
        
        for fold, (train_idx, val_idx) in enumerate(skf.split(X, y), 1):
            X_train, X_val = X.iloc[train_idx], X.iloc[val_idx]
            y_train, y_val = y.iloc[train_idx], y.iloc[val_idx]
            
            # Train model for this fold
            fold_model = clone(self.model)
            fold_model.fit(X_train, y_train)
            
            # Make predictions
            y_pred = fold_model.predict(X_val)
            
            # Calculate metrics
            from sklearn.metrics import accuracy_score, f1_score
            metrics['accuracy'].append(accuracy_score(y_val, y_pred))
            metrics['weighted_f1'].append(f1_score(y_val, y_pred, average='weighted'))
            
            # Class-wise F1 scores
            for class_label in metrics['class_f1']:
                class_f1 = f1_score(y_val == class_label, y_pred == class_label)
                metrics['class_f1'][class_label].append(class_f1)
        
        # Print results
        print(f"\nAccuracy: {np.mean(metrics['accuracy']):.3f} (+/- {np.std(metrics['accuracy'])*2:.3f})")
        print(f"Weighted F1: {np.mean(metrics['weighted_f1']):.3f} (+/- {np.std(metrics['weighted_f1'])*2:.3f})")
        
        print("\nClass-wise F1 scores:")
        for class_label, scores in metrics['class_f1'].items():
            print(f"{class_label}:")
            print(f"  Mean: {np.mean(scores):.3f}")
            print(f"  Std: {np.std(scores):.3f}")