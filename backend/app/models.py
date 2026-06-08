from datetime import datetime

from .extensions import db


class Rule(db.Model):
    __tablename__ = "rules"

    id = db.Column(db.Integer, primary_key=True)
    subject = db.Column(db.String(20), unique=True, nullable=False)
    min_interval_days = db.Column(db.Integer, nullable=False, default=7)
    max_daily_slots = db.Column(db.Integer, nullable=False, default=20)
    allow_weekend = db.Column(db.Boolean, nullable=False, default=False)
    passing_score = db.Column(db.Integer, nullable=False, default=90)
    makeup_wait_days = db.Column(db.Integer, nullable=False, default=10)
    enabled = db.Column(db.Boolean, nullable=False, default=True)

    def to_dict(self):
        return {
            "id": self.id,
            "subject": self.subject,
            "minIntervalDays": self.min_interval_days,
            "maxDailySlots": self.max_daily_slots,
            "allowWeekend": self.allow_weekend,
            "passingScore": self.passing_score,
            "makeupWaitDays": self.makeup_wait_days,
            "enabled": self.enabled,
        }


class Appointment(db.Model):
    __tablename__ = "appointments"

    id = db.Column(db.Integer, primary_key=True)
    student_name = db.Column(db.String(60), nullable=False)
    id_number = db.Column(db.String(30), nullable=False)
    subject = db.Column(db.String(20), nullable=False)
    exam_date = db.Column(db.Date, nullable=False)
    timeslot = db.Column(db.String(20), nullable=False)
    status = db.Column(db.String(20), nullable=False, default="已预约")
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "studentName": self.student_name,
            "idNumber": self.id_number,
            "subject": self.subject,
            "examDate": self.exam_date.isoformat(),
            "timeslot": self.timeslot,
            "status": self.status,
            "createdAt": self.created_at.isoformat(timespec="seconds"),
        }


class ExamQuestion(db.Model):
    __tablename__ = "exam_questions"

    id = db.Column(db.Integer, primary_key=True)
    subject = db.Column(db.String(20), nullable=False)
    question = db.Column(db.String(255), nullable=False)
    options = db.Column(db.JSON, nullable=False)
    answer = db.Column(db.String(10), nullable=False)

    def to_public_dict(self):
        return {
            "id": self.id,
            "subject": self.subject,
            "question": self.question,
            "options": self.options,
        }


class ExamRecord(db.Model):
    __tablename__ = "exam_records"

    id = db.Column(db.Integer, primary_key=True)
    student_name = db.Column(db.String(60), nullable=False)
    subject = db.Column(db.String(20), nullable=False)
    score = db.Column(db.Integer, nullable=False)
    total_questions = db.Column(db.Integer, nullable=False)
    correct_count = db.Column(db.Integer, nullable=False)
    passed = db.Column(db.Boolean, nullable=False, default=False)
    details = db.Column(db.JSON, nullable=False, default=list)
    submitted_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "studentName": self.student_name,
            "subject": self.subject,
            "score": self.score,
            "totalQuestions": self.total_questions,
            "correctCount": self.correct_count,
            "passed": self.passed,
            "details": self.details,
            "submittedAt": self.submitted_at.isoformat(timespec="seconds"),
        }


class Makeup(db.Model):
    __tablename__ = "makeups"

    id = db.Column(db.Integer, primary_key=True)
    student_name = db.Column(db.String(60), nullable=False)
    original_subject = db.Column(db.String(20), nullable=False)
    failed_score = db.Column(db.Integer, nullable=False)
    scheduled_date = db.Column(db.Date, nullable=True)
    status = db.Column(db.String(20), nullable=False, default="待安排")
    notes = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "studentName": self.student_name,
            "originalSubject": self.original_subject,
            "failedScore": self.failed_score,
            "scheduledDate": self.scheduled_date.isoformat()
            if self.scheduled_date
            else None,
            "status": self.status,
            "notes": self.notes,
            "createdAt": self.created_at.isoformat(timespec="seconds"),
        }
