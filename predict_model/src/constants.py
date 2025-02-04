TACTICAL_CATEGORIES = {
    'OFFENSIVE': {
        'power_hitting': {
            'actions': ['Home Run', 'Double', 'Triple'],
            'contexts': {
                'min_runners': 1,
                'scoring_position': True,
                'min_pressure': 1.5
            }
        },
        'contact_hitting': {
            'actions': ['Single', 'Ground Ball'],
            'contexts': {
                'max_pressure': 1.5,
                'max_outs': 2
            }
        },
        'small_ball': {
            'actions': ['Sac Bunt', 'Sac Fly', 'Bunt Groundout'],
            'contexts': {
                'score_diff_range': (-2, 2),
                'max_outs': 1
            }
        },
        'patient_hitting': {
            'actions': ['Walk', 'Hit By Pitch', 'Intent Walk'],
            'contexts': {
                'min_balls': 2,
                'max_strikes': 1
            }
        },
    },
    'BASERUNNING': {
        'aggressive_baserunning': {
            'actions': ['Stolen Base 2B', 'Stolen Base 3B', 'Stolen Base Home', 'Triple'],
            'contexts': {
                'max_outs': 1,
                'min_offensive_opportunity': 1.0
            }
        },
        'conservative_baserunning': {
            'actions': ['Pickoff', 'Caught Stealing', 'Pickoff Caught Stealing'],
            'contexts': {
                'min_pressure': 1.5
            }
        },
    },
    'DEFENSIVE': {
        'defensive_outs': {
            'actions': ['Groundout', 'Flyout', 'Lineout', 'Pop Out', 'Forceout'],
            'contexts': {
                'min_defensive_pressure': 1.0
            }
        },
        'strikeout_pitching': {
            'actions': ['Strikeout', 'Strikeout Double Play'],
            'contexts': {
                'min_strikes': 2
            }
        },
        'double_play': {
            'actions': ['Double Play', 'Grounded Into DP', 'Triple Play'],
            'contexts': {
                'min_runners': 1,
                'max_outs': 2
            }
        },
        'field_defense': {
            'actions': ['Field Error', 'Pickoff', 'Caught Stealing'],
            'contexts': {
                'min_defensive_pressure': 1.5
            }
        }
    }
}

# Trọng số cho các context khác nhau
CONTEXT_WEIGHTS = {
    'score_situation': 0.3,
    'count_situation': 0.2,
    'runner_situation': 0.25,
    'game_stage': 0.25
}

# Ngưỡng cho các tình huống high-leverage
HIGH_LEVERAGE_THRESHOLDS = {
    'late_innings': 7,
    'close_score': 2,
    'high_pressure': 1.5,
    'scoring_position': True
}

# Build ACTION_TO_TACTIC với context
ACTION_TO_TACTIC = {}
for category in TACTICAL_CATEGORIES.values():
    for tactic, data in category.items():
        for action in data['actions']:
            if action not in ACTION_TO_TACTIC:
                ACTION_TO_TACTIC[action] = []
            ACTION_TO_TACTIC[action].append({
                'tactic': tactic,
                'contexts': data['contexts']
            })

# Các event hợp lệ
VALID_EVENTS = {
    'hitting': [action for category in ['power_hitting', 'contact_hitting', 'small_ball', 'patient_hitting']
               for action in TACTICAL_CATEGORIES['OFFENSIVE'][category]['actions']],
    'baserunning': [action for category in TACTICAL_CATEGORIES['BASERUNNING']
                    for action in TACTICAL_CATEGORIES['BASERUNNING'][category]['actions']],
    'fielding': [action for category in TACTICAL_CATEGORIES['DEFENSIVE']
                 for action in TACTICAL_CATEGORIES['DEFENSIVE'][category]['actions']]
}