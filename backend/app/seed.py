from datetime import date

from .extensions import db
from .models import Appointment, ExamQuestion, Makeup, Rule


def seed_data():
    if not Rule.query.first():
        rules = [
            Rule(subject="科目一", min_interval_days=3, max_daily_slots=30, passing_score=90),
            Rule(subject="科目二", min_interval_days=7, max_daily_slots=18, passing_score=80),
            Rule(subject="科目三", min_interval_days=10, max_daily_slots=15, passing_score=90),
            Rule(subject="科目四", min_interval_days=3, max_daily_slots=30, passing_score=90),
        ]
        db.session.add_all(rules)

    if not ExamQuestion.query.first():
        questions = [
            ExamQuestion(
                subject="科目一",
                question="驾驶机动车通过没有交通信号灯控制的路口时应当如何通行？",
                options=["快速通过", "减速慢行并让行", "连续鸣笛", "靠左通行"],
                answer="B",
            ),
            ExamQuestion(
                subject="科目一",
                question="机动车驾驶证有效期分为几年、十年和长期？",
                options=["三年", "四年", "六年", "八年"],
                answer="C",
            ),
            ExamQuestion(
                subject="科目一",
                question="驾驶机动车遇行人正在通过人行横道时应怎样做？",
                options=["停车让行", "加速绕行", "鸣笛催促", "从行人身后穿过"],
                answer="A",
            ),
            ExamQuestion(
                subject="科目四",
                question="夜间会车时应在距对向来车多少米以外改用近光灯？",
                options=["30米", "50米", "100米", "150米"],
                answer="D",
            ),
            ExamQuestion(
                subject="科目四",
                question="车辆发生故障无法移动时，危险报警闪光灯应如何使用？",
                options=["无需开启", "白天不开启", "持续开启", "只在夜间开启"],
                answer="C",
            ),
            ExamQuestion(
                subject="科目四",
                question="雨天行车制动距离会怎样变化？",
                options=["缩短", "不变", "延长", "无法判断"],
                answer="C",
            ),
        ]
        db.session.add_all(questions)

    if not Appointment.query.first():
        db.session.add(
            Appointment(
                student_name="张三",
                id_number="110101199901010011",
                subject="科目一",
                exam_date=date(2026, 6, 8),
                timeslot="09:00-10:00",
                status="已预约",
            )
        )

    if not Makeup.query.first():
        db.session.add(
            Makeup(
                student_name="李四",
                original_subject="科目二",
                failed_score=72,
                status="待安排",
                notes="倒车入库项目失分较多",
            )
        )

    db.session.commit()
