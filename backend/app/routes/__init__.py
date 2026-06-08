from .appointments import appointments_bp
from .exams import exams_bp
from .makeups import makeups_bp
from .rules import rules_bp
from .scores import scores_bp


def register_blueprints(app):
    app.register_blueprint(appointments_bp)
    app.register_blueprint(exams_bp)
    app.register_blueprint(scores_bp)
    app.register_blueprint(makeups_bp)
    app.register_blueprint(rules_bp)
