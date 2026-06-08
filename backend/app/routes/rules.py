from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Rule

rules_bp = Blueprint("rules", __name__, url_prefix="/api/rules")


@rules_bp.get("")
def list_rules():
    rules = Rule.query.order_by(Rule.id.asc()).all()
    return jsonify([rule.to_dict() for rule in rules])


@rules_bp.patch("/<int:rule_id>")
def update_rule(rule_id):
    rule = Rule.query.get_or_404(rule_id)
    payload = request.get_json() or {}

    int_fields = {
        "minIntervalDays": "min_interval_days",
        "maxDailySlots": "max_daily_slots",
        "passingScore": "passing_score",
        "makeupWaitDays": "makeup_wait_days",
    }
    for api_key, model_key in int_fields.items():
        if api_key in payload:
            value = int(payload[api_key])
            if value < 0:
                return jsonify({"message": f"{api_key} 不能小于 0"}), 400
            setattr(rule, model_key, value)

    if "allowWeekend" in payload:
        rule.allow_weekend = bool(payload["allowWeekend"])
    if "enabled" in payload:
        rule.enabled = bool(payload["enabled"])

    db.session.commit()
    return jsonify(rule.to_dict())
