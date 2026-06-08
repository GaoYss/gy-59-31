from datetime import date, datetime, timedelta

from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Appointment, Rule

appointments_bp = Blueprint("appointments", __name__, url_prefix="/api/appointments")


def parse_exam_date(value):
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except (TypeError, ValueError):
        return None


def validate_appointment(payload):
    required = ["studentName", "idNumber", "subject", "examDate", "timeslot"]
    missing = [field for field in required if not payload.get(field)]
    if missing:
        return f"缺少字段：{', '.join(missing)}", None

    exam_date = parse_exam_date(payload.get("examDate"))
    if not exam_date:
        return "考试日期格式应为 YYYY-MM-DD", None
    if exam_date < date.today():
        return "不能预约过去日期", None

    rule = Rule.query.filter_by(subject=payload["subject"]).first()
    if not rule or not rule.enabled:
        return "该科目暂未开放预约", None
    if exam_date.weekday() >= 5 and not rule.allow_weekend:
        return "该科目规则不允许周末预约", None

    daily_count = Appointment.query.filter(
        Appointment.subject == payload["subject"],
        Appointment.exam_date == exam_date,
        Appointment.status.in_(["已预约", "已确认"]),
    ).count()
    if daily_count >= rule.max_daily_slots:
        return "当日该科目预约名额已满", None

    earliest_date = date.today() + timedelta(days=rule.min_interval_days)
    if exam_date < earliest_date:
        return f"该科目需至少提前 {rule.min_interval_days} 天预约", None

    active = Appointment.query.filter(
        Appointment.id_number == payload["idNumber"],
        Appointment.subject == payload["subject"],
        Appointment.status.in_(["已预约", "已确认"]),
    ).first()
    if active:
        return "该学员已有同科目有效预约", None

    return None, exam_date


@appointments_bp.get("")
def list_appointments():
    subject = request.args.get("subject")
    status = request.args.get("status")
    query = Appointment.query.order_by(Appointment.exam_date.asc(), Appointment.timeslot.asc())
    if subject:
        query = query.filter_by(subject=subject)
    if status:
        query = query.filter_by(status=status)
    return jsonify([item.to_dict() for item in query.all()])


@appointments_bp.post("")
def create_appointment():
    payload = request.get_json() or {}
    error, exam_date = validate_appointment(payload)
    if error:
        return jsonify({"message": error}), 400

    appointment = Appointment(
        student_name=payload["studentName"].strip(),
        id_number=payload["idNumber"].strip(),
        subject=payload["subject"],
        exam_date=exam_date,
        timeslot=payload["timeslot"],
        status="已预约",
    )
    db.session.add(appointment)
    db.session.commit()
    return jsonify(appointment.to_dict()), 201


@appointments_bp.patch("/<int:appointment_id>")
def update_appointment_status(appointment_id):
    appointment = Appointment.query.get_or_404(appointment_id)
    payload = request.get_json() or {}
    status = payload.get("status")
    if status not in ["已预约", "已确认", "已取消", "已完成"]:
        return jsonify({"message": "无效预约状态"}), 400
    appointment.status = status
    db.session.commit()
    return jsonify(appointment.to_dict())
