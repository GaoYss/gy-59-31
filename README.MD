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
├── start.ps1                   # 一键启动脚本 (Windows PowerShell)
├── start.sh                    # 一键启动脚本 (macOS / Linux Bash)
└── docker-compose.yml
```

## 一键启动（推荐）

项目提供了两个跨平台脚本，**自动检查环境、安装依赖、启动前后端、验证健康状态、出错时给出修复建议**。
**不要再手动进入前后端目录分开操作。**

### 方式一：本地开发模式（推荐日常开发）

| 系统 | 命令 | 备注 |
|---|---|---|
| **Windows** (PowerShell) | `.\start.ps1 local` | 需要先安装 Python 3.10+ 和 Node.js 18+ |
| **macOS / Linux** (Bash) | `./start.sh local` | 首次执行需 `chmod +x start.sh` |

可选：国内用户加 `USE_MIRROR=1` 使用镜像加速下载依赖：

```powershell
# Windows PowerShell
$env:USE_MIRROR='1'; .\start.ps1 local
```

```bash
# macOS / Linux
USE_MIRROR=1 ./start.sh local
```

### 方式二：Docker 模式（推荐部署 / 不希望安装本地依赖）

| 系统 | 命令 | 备注 |
|---|---|---|
| **Windows** (PowerShell) | `.\start.ps1 docker` | 需要先安装并启动 Docker Desktop |
| **macOS / Linux** (Bash) | `./start.sh docker` | 同上，需安装 docker 与 compose 插件 |

### 启动完成后

启动成功会看到绿色的 `========== 服务已全部就绪 ==========` 提示，并输出访问地址：

- **前端入口**：http://127.0.0.1:5173
- **后端健康检查**：http://127.0.0.1:5000/api/health

### 停止服务

```powershell
# Windows - 停止本地
.\start.ps1 stop-local

# Windows - 停止 Docker
.\start.ps1 stop-docker
```

```bash
# macOS / Linux - 停止本地
./start.sh stop-local

# macOS / Linux - 停止 Docker
./start.sh stop-docker
```

### 启动失败怎么办？

脚本会自动检测并明确指出问题 + 修复方法，常见场景：

| 报错场景 | 修复提示示例 |
|---|---|
| 未安装 Python / Node | 给出各平台安装命令和下载链接 |
| 版本过低 | 给出升级命令（brew / nvm / 直接下载） |
| 端口被占用 (5000 / 5173) | 输出占用 PID + `lsof` / `taskkill` 结束命令 |
| 依赖安装失败 | 建议切换 `USE_MIRROR=1` 或手动执行报错命令看详情 |
| Docker 未启动 | 给出 macOS / Linux / Windows 启动 Docker 的具体命令 |
| 容器构建失败 | 建议配置 Docker 镜像加速 + 单步调试命令 |
| 服务启动崩溃 | 自动打印近 30 行日志 + `docker compose logs ...` 排查命令 |

查看完整帮助：`.\start.ps1 help` 或 `./start.sh help`

## 环境要求（脚本会自动校验）

| 组件 | 最低版本 | 用途 |
|---|---|---|
| Python | 3.10+ | 本地模式运行 Flask 后端 |
| Node.js | 18+ | 本地模式运行 Vite 前端 |
| Docker + compose | 24+ | Docker 模式一键构建启动 |

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
