from datetime import datetime

from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Makeup

makeups_bp = Blueprint("makeups", __name__, url_prefix="/api/makeups")


def parse_date(value):
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        return "invalid"


@makeups_bp.get("")
def list_makeups():
    status = request.args.get("status")
    query = Makeup.query.order_by(Makeup.created_at.desc())
    if status:
        query = query.filter_by(status=status)
    return jsonify([item.to_dict() for item in query.all()])


@makeups_bp.post("")
def create_makeup():
    payload = request.get_json() or {}
    required = ["studentName", "originalSubject", "failedScore"]
    missing = [field for field in required if payload.get(field) in (None, "")]
    if missing:
        return jsonify({"message": f"缺少字段：{', '.join(missing)}"}), 400

    scheduled_date = parse_date(payload.get("scheduledDate"))
    if scheduled_date == "invalid":
        return jsonify({"message": "补考日期格式应为 YYYY-MM-DD"}), 400

    makeup = Makeup(
        student_name=payload["studentName"].strip(),
        original_subject=payload["originalSubject"],
        failed_score=int(payload["failedScore"]),
        scheduled_date=scheduled_date,
        status=payload.get("status", "待安排"),
        notes=payload.get("notes"),
    )
    db.session.add(makeup)
    db.session.commit()
    return jsonify(makeup.to_dict()), 201


@makeups_bp.patch("/<int:makeup_id>")
def update_makeup(makeup_id):
    makeup = Makeup.query.get_or_404(makeup_id)
    payload = request.get_json() or {}

    if "scheduledDate" in payload:
        scheduled_date = parse_date(payload.get("scheduledDate"))
        if scheduled_date == "invalid":
            return jsonify({"message": "补考日期格式应为 YYYY-MM-DD"}), 400
        makeup.scheduled_date = scheduled_date
    if "status" in payload:
        if payload["status"] not in ["待安排", "已安排", "已通过", "已取消"]:
            return jsonify({"message": "无效补考状态"}), 400
        makeup.status = payload["status"]
    if "notes" in payload:
        makeup.notes = payload["notes"]

    db.session.commit()
    return jsonify(makeup.to_dict())
