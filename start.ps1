$ErrorActionPreference = "Stop"

$BACKEND_PORT = 5000
$FRONTEND_PORT = 5173
$BACKEND_HEALTH_URL = "http://127.0.0.1:$BACKEND_PORT/api/health"
$FRONTEND_HEALTH_URL = "http://127.0.0.1:$FRONTEND_PORT"
$MAX_RETRIES = 30
$RETRY_INTERVAL = 2
$PYTHON_MIN_VER = [Version]"3.10.0"
$NODE_MIN_VER = [Version]"18.0.0"

function Write-Status($msg) { Write-Host "`n[*] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "[-] $msg" -ForegroundColor Red }
function Write-Hint($msg)  { Write-Host "    -> $msg" -ForegroundColor DarkCyan }

function Wait-HealthCheck {
    param([string]$Url, [string]$Label, [int]$Port, [int]$Retries = $MAX_RETRIES)

    Write-Status "等待 $Label 启动 ($Url) ..."
    for ($i = 1; $i -le $Retries; $i++) {
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400) {
                Write-Ok "$Label 已就绪 (HTTP $($resp.StatusCode))"
                return $true
            }
        } catch { }
        Write-Host "  重试 $i/$Retries ..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $RETRY_INTERVAL
    }
    Write-Fail "$Label 在 ${Retries} 次重试后仍未就绪"
    $used = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($used) {
        Write-Warn "端口 $Port 已被占用 (PID: $($used.OwningProcess -join ', '))"
        Write-Hint "打开任务管理器，搜索上述 PID 并结束进程，或执行: netstat -ano | findstr :$Port"
    } else {
        Write-Warn "端口 $Port 无监听，服务可能启动过程中崩溃"
    }
    return $false
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Check-PortAvailable {
    param([int]$Port, [string]$Label)
    $used = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($used) {
        Write-Fail "端口 $Port 已被占用 (PID: $($used.OwningProcess -join ', '))，无法启动 $Label"
        Write-Hint "方案 1: 打开任务管理器 -> 详细信息 -> 搜索 PID 结束进程"
        Write-Hint "方案 2: 执行: netstat -ano | findstr :$Port   再执行: taskkill /PID [PID号] /F"
        return $false
    }
    return $true
}

function Check-Python {
    if (-not (Test-Command "python")) {
        Write-Fail "未检测到 Python 命令"
        Write-Hint "下载安装 Python 3.10+: https://www.python.org/downloads/"
        Write-Hint "安装时务必勾选 'Add Python to PATH'，安装后重新打开终端"
        return $false
    }
    try {
        $verStr = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>&1
        $ver = [Version]$verStr.Trim()
        if ($ver -lt $PYTHON_MIN_VER) {
            Write-Fail "Python 版本过低: $ver（最低要求 $PYTHON_MIN_VER）"
            Write-Hint "升级 Python: https://www.python.org/downloads/  下载覆盖安装即可"
            return $false
        }
        Write-Ok "Python 版本检查通过: $ver"
        return $true
    } catch {
        Write-Warn "无法验证 Python 版本，继续尝试启动..."
        return $true
    }
}

function Check-Node {
    if (-not (Test-Command "node")) {
        Write-Fail "未检测到 Node.js 命令"
        Write-Hint "下载安装 Node.js 18+: https://nodejs.org/  (LTS 版本)"
        Write-Hint "安装后重新打开终端，或执行: refreshenv"
        return $false
    }
    try {
        $verStr = node -v 2>&1
        $ver = [Version]($verStr.Trim().TrimStart('v'))
        if ($ver -lt $NODE_MIN_VER) {
            Write-Fail "Node.js 版本过低: $verStr（最低要求 v$NODE_MIN_VER）"
            Write-Hint "升级 Node.js: https://nodejs.org/  下载覆盖安装即可"
            return $false
        }
        Write-Ok "Node.js 版本检查通过: $verStr"
        return $true
    } catch {
        Write-Warn "无法验证 Node.js 版本，继续尝试启动..."
        return $true
    }
}

function Start-Local {
    Write-Status "========== 本地模式启动 =========="

    if (-not (Check-Python)) { exit 1 }
    if (-not (Check-Node))   { exit 1 }

    if (-not (Check-PortAvailable -Port $BACKEND_PORT  -Label "后端")) { exit 1 }
    if (-not (Check-PortAvailable -Port $FRONTEND_PORT -Label "前端")) { exit 1 }

    $backendDir = Join-Path $PSScriptRoot "backend"
    $frontendDir = Join-Path $PSScriptRoot "frontend"
    $venvDir = Join-Path $backendDir ".venv"
    $venvPython = Join-Path $venvDir "Scripts" "python.exe"
    $venvPip = Join-Path $venvDir "Scripts" "pip.exe"

    if (-not (Test-Path $venvDir)) {
        Write-Status "创建 Python 虚拟环境..."
        python -m venv $venvDir
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "创建虚拟环境失败"
            Write-Hint "检查磁盘空间，或手动执行: python -m venv $venvDir"
            exit 1
        }
        Write-Ok "虚拟环境已创建"
    }

    Write-Status "安装后端依赖..."
    $pipArgs = @("install", "-r", (Join-Path $backendDir "requirements.txt"), "-q")
    if ($env:USE_MIRROR -eq "1" -or $env:USE_MIRROR -eq "true") {
        $pipArgs += @("-i", "https://pypi.tuna.tsinghua.edu.cn/simple")
    }
    & $venvPip @pipArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "后端依赖安装失败"
        Write-Hint "使用国内镜像重试: `$env:USE_MIRROR='1'; .\start.ps1 local"
        Write-Hint "或手动激活虚拟环境后执行: pip install -r backend\requirements.txt 查看详细错误"
        exit 1
    }
    Write-Ok "后端依赖已就绪"

    Write-Status "安装前端依赖..."
    Push-Location $frontendDir
    if (Test-Path "node_modules") {
        Write-Ok "node_modules 已存在，跳过 npm install"
    } else {
        if ($env:USE_MIRROR -eq "1" -or $env:USE_MIRROR -eq "true") {
            npm install --silent --registry=https://registry.npmmirror.com 2>$null
        } else {
            npm install --silent 2>$null
        }
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-Fail "前端依赖安装失败 (npm install 返回非零)"
            Write-Hint "使用国内镜像重试: `$env:USE_MIRROR='1'; .\start.ps1 local"
            Write-Hint "或手动执行: cd frontend; npm install 查看详细错误"
            Write-Hint "清除缓存重试: 删除 frontend\node_modules 和 frontend\package-lock.json 后再试"
            exit 1
        }
    }
    Pop-Location
    Write-Ok "前端依赖已就绪"

    Write-Status "启动后端服务..."
    $backendProc = Start-Process -FilePath $venvPython -ArgumentList "wsgi.py" -WorkingDirectory $backendDir -PassThru -NoNewWindow
    $script:localProcs += $backendProc

    $backendOk = Wait-HealthCheck -Url $BACKEND_HEALTH_URL -Label "后端" -Port $BACKEND_PORT
    if (-not $backendOk) {
        Stop-Local
        Write-Fail "后端启动失败 (进程 ID: $($backendProc.Id))"
        Write-Hint "1. 检查 backend 目录下是否有错误日志输出"
        Write-Hint "2. 手动启动查看详情: cd backend; .\.venv\Scripts\python.exe wsgi.py"
        Write-Hint "3. 确认后端端口 $BACKEND_PORT 未被防火墙拦截"
        exit 1
    }

    Write-Status "启动前端服务..."
    $frontendProc = Start-Process -FilePath "npm" -ArgumentList "run","dev" -WorkingDirectory $frontendDir -PassThru -NoNewWindow
    $script:localProcs += $frontendProc

    $frontendOk = Wait-HealthCheck -Url $FRONTEND_HEALTH_URL -Label "前端" -Port $FRONTEND_PORT
    if (-not $frontendOk) {
        Stop-Local
        Write-Fail "前端启动失败 (进程 ID: $($frontendProc.Id))"
        Write-Hint "1. 手动启动查看详情: cd frontend; npm run dev"
        Write-Hint "2. 确认前端端口 $FRONTEND_PORT 未被防火墙拦截"
        exit 1
    }

    Write-Ok "========== 本地服务已全部就绪 =========="
    Write-Host "`n  后端健康检查: http://127.0.0.1:$BACKEND_PORT/api/health" -ForegroundColor White
    Write-Host "  前端访问入口: http://127.0.0.1:$FRONTEND_PORT`n" -ForegroundColor White
    Write-Hint "停止服务: .\start.ps1 stop-local"
}

function Stop-Local {
    if ($script:localProcs) {
        Write-Status "停止本地进程..."
        foreach ($proc in $script:localProcs) {
            try {
                if (-not $proc.HasExited) {
                    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                    Write-Ok "已停止进程 $($proc.Id)"
                }
            } catch { }
        }
    }
}

function Start-Docker {
    Write-Status "========== Docker 模式启动 =========="

    if (-not (Test-Command "docker")) {
        Write-Fail "未检测到 docker 命令"
        Write-Hint "Windows: 安装 Docker Desktop  https://www.docker.com/products/docker-desktop/"
        Write-Hint "macOS:   brew install --cask docker  或从官网下载 Docker Desktop"
        Write-Hint "Linux:   参考 https://docs.docker.com/engine/install/  安装 docker 与 docker compose 插件"
        exit 1
    }

    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Docker 守护进程未运行"
        if ($env:OS -like "*Windows*") {
            Write-Hint "启动 Docker Desktop: 开始菜单搜索 Docker Desktop 打开"
            Write-Hint "或在 PowerShell 执行: Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'"
        } elseif ($env:HOME -like "*Mac*" -or $IsMacOS) {
            Write-Hint "启动 Docker Desktop: open -a Docker"
        } else {
            Write-Hint "Linux 启动服务: sudo systemctl start docker  或 sudo service docker start"
        }
        exit 1
    }
    Write-Ok "Docker 守护进程正常运行"

    $composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
    Write-Status "构建并启动容器 (docker compose up --build -d)..."
    docker compose -f $composeFile up --build -d 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "容器构建/启动失败"
        Write-Hint "1. 检查上方构建日志，通常是依赖下载失败或 Dockerfile 错误"
        Write-Hint "2. 国内用户可配置 Docker 镜像加速: Docker Desktop -> Settings -> Docker Engine 添加 registry-mirrors"
        Write-Hint "   推荐镜像: https://docker.mirrors.ustc.edu.cn / https://hub-mirror.c.163.com"
        Write-Hint "3. 单步调试: docker compose -f `"$composeFile`" build --no-cache"
        exit 1
    }
    Write-Ok "容器已启动"

    $backendOk = Wait-HealthCheck -Url $BACKEND_HEALTH_URL -Label "后端容器" -Port $BACKEND_PORT
    if (-not $backendOk) {
        Write-Fail "后端容器健康检查失败"
        Write-Warn "最近 30 条后端日志:"
        docker compose -f $composeFile logs backend --tail 30
        Write-Hint "手动查看完整日志: docker compose -f `"$composeFile`" logs backend -f"
        Write-Hint "重启容器: docker compose -f `"$composeFile`" restart backend"
        exit 1
    }

    $frontendOk = Wait-HealthCheck -Url $FRONTEND_HEALTH_URL -Label "前端容器" -Port $FRONTEND_PORT
    if (-not $frontendOk) {
        Write-Fail "前端容器健康检查失败"
        Write-Warn "最近 30 条前端日志:"
        docker compose -f $composeFile logs frontend --tail 30
        Write-Hint "手动查看完整日志: docker compose -f `"$composeFile`" logs frontend -f"
        Write-Hint "重启容器: docker compose -f `"$composeFile`" restart frontend"
        exit 1
    }

    Write-Ok "========== Docker 服务已全部就绪 =========="
    Write-Host "`n  后端健康检查: http://127.0.0.1:$BACKEND_PORT/api/health" -ForegroundColor White
    Write-Host "  前端访问入口: http://127.0.0.1:$FRONTEND_PORT`n" -ForegroundColor White
    Write-Hint "停止服务: .\start.ps1 stop-docker"
}

function Stop-Docker {
    $composeFile = Join-Path $PSScriptRoot "docker-compose.yml"
    Write-Status "停止 Docker 容器..."
    docker compose -f $composeFile down 2>&1
    Write-Ok "容器已停止"
}

function Show-Help {
    Write-Host @"

驾考科目预约系统 - 统一启动脚本 (Windows PowerShell)

用法:
  .\start.ps1 <命令>

命令:
  local       本地开发模式（环境检查 -> 创建 venv -> 安装依赖 -> 启动前后端 -> 健康验证）
  docker      Docker Compose 模式（环境检查 -> 构建镜像 -> 启动容器 -> 健康验证）
  stop-local  停止本地前后端进程
  stop-docker 停止并移除 Docker 容器
  help        显示此帮助信息

环境变量 (可选):
  USE_MIRROR=1   使用国内镜像源加速 (清华 pip + npmmirror npm)

示例:
  .\start.ps1 local
  `$env:USE_MIRROR='1'; .\start.ps1 local
  .\start.ps1 docker
  .\start.ps1 stop-local

跨平台: macOS / Linux 用户请使用同目录的 start.sh (bash 脚本)
"@
}

$script:localProcs = @()

try {
    switch -Regex ($args[0]) {
        "^(local|-local|--local)$"       { Start-Local }
        "^(docker|-docker|--docker)$"    { Start-Docker }
        "^(stop-local)$"                  { Stop-Local }
        "^(stop-docker)$"                 { Stop-Docker }
        "^(help|-h|--help)$"              { Show-Help }
        $null                             { Show-Help; exit 1 }
        default                           { Show-Help; exit 1 }
    }
} catch {
    Write-Fail "启动过程中发生异常: $_"
    if ($args[0] -like "local*") { Stop-Local }
    exit 1
}
