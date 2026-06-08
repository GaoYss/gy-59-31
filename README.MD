# 驾考科目预约系统

基于 Flask + Vue 的驾考科目预约管理系统，覆盖科目预约、模拟考试、成绩查询、补考管理和约考规则设置。项目采用前后端分离和模块化结构，后端按业务蓝图拆分，前端按视图、组件、API 层拆分。

## 功能模块

- 科目预约：创建预约、查看预约列表、维护预约状态，并按规则校验提前天数、每日名额、周末预约和重复预约。
- 模拟考试：按科目加载题目、提交答案、自动评分，未通过时自动生成补考记录。
- 成绩查询：按学员姓名和科目筛选考试成绩。
- 补考管理：新增补考、安排补考日期、更新补考状态。
- 约考规则设置：配置各科目的提前预约天数、每日名额、合格线、补考等待天数、是否允许周末预约和是否开放预约。

## 项目结构

```text
.
├── backend
│   ├── app
│   │   ├── routes              # Flask 蓝图路由
│   │   ├── __init__.py         # 应用工厂
│   │   ├── models.py           # 数据模型
│   │   ├── seed.py             # 初始化示例数据
│   │   └── extensions.py       # 扩展实例
│   ├── Dockerfile
│   ├── requirements.txt
│   └── wsgi.py
├── frontend
│   ├── src
│   │   ├── api                 # 前端请求封装
│   │   ├── components          # 通用组件
│   │   ├── constants           # 常量选项
│   │   ├── views               # 业务页面
│   │   ├── App.vue
│   │   └── main.js
│   ├── Dockerfile
│   ├── package.json
│   └── vite.config.js
└── docker-compose.yml
```

## Docker Compose 启动

```bash
docker compose up --build
```

启动后访问：

- 前端：http://127.0.0.1:5173
- 后端健康检查：http://127.0.0.1:5000/api/health

## 本地开发启动

后端：

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python wsgi.py
```

前端：

```bash
cd frontend
npm install
npm run dev
```

## API 概览

- `GET /api/health`
- `GET /api/appointments`
- `POST /api/appointments`
- `PATCH /api/appointments/<id>`
- `GET /api/exams/questions?subject=科目一`
- `POST /api/exams/submit`
- `GET /api/scores`
- `GET /api/makeups`
- `POST /api/makeups`
- `PATCH /api/makeups/<id>`
- `GET /api/rules`
- `PATCH /api/rules/<id>`

## 默认数据

首次启动会自动创建 SQLite 数据库并写入：

- 科目一、科目二、科目三、科目四默认约考规则
- 科目一和科目四示例题目
- 一条预约示例记录
- 一条补考示例记录
