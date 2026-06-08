from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import ExamQuestion, ExamRecord, Makeup, Rule

exams_bp = Blueprint("exams", __name__, url_prefix="/api/exams")


@exams_bp.get("/questions")
def list_questions():
    subject = request.args.get("subject", "科目一")
    limit = min(int(request.args.get("limit", 6)), 20)
    questions = (
        ExamQuestion.query.filter_by(subject=subject)
        .order_by(ExamQuestion.id.asc())
        .limit(limit)
        .all()
    )
    return jsonify([question.to_public_dict() for question in questions])


@exams_bp.post("/submit")
def submit_exam():
    payload = request.get_json() or {}
    student_name = payload.get("studentName", "").strip()
    subject = payload.get("subject", "")
    answers = payload.get("answers", {})

    if not student_name or not subject or not isinstance(answers, dict):
        return jsonify({"message": "请提交学员姓名、科目和答案"}), 400

    question_ids = [int(question_id) for question_id in answers.keys()]
    questions = ExamQuestion.query.filter(ExamQuestion.id.in_(question_ids)).all()
    if not questions:
        return jsonify({"message": "没有可评分的题目"}), 400

    details = []
    correct_count = 0
    for question in questions:
        chosen = answers.get(str(question.id))
        correct = chosen == question.answer
        correct_count += 1 if correct else 0
        details.append(
            {
                "questionId": question.id,
                "question": question.question,
                "chosen": chosen,
                "answer": question.answer,
                "correct": correct,
            }
        )

    score = round(correct_count / len(questions) * 100)
    rule = Rule.query.filter_by(subject=subject).first()
    passing_score = rule.passing_score if rule else 90
    passed = score >= passing_score

    record = ExamRecord(
        student_name=student_name,
        subject=subject,
        score=score,
        total_questions=len(questions),
        correct_count=correct_count,
        passed=passed,
        details=details,
    )
    db.session.add(record)

    makeup = None
    if not passed:
        makeup = Makeup(
            student_name=student_name,
            original_subject=subject,
            failed_score=score,
            status="待安排",
            notes=f"模拟考试未达合格线 {passing_score} 分",
        )
        db.session.add(makeup)

    db.session.commit()
    return jsonify({"record": record.to_dict(), "makeup": makeup.to_dict() if makeup else None})
