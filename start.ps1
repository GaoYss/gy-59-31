$ErrorActionPreference = "Stop"

$BACKEND_PORT = 5000
$FRONTEND_PORT = 5173
$BACKEND_HEALTH_URL = "http://127.0.0.1:$BACKEND_PORT/api/health"
$FRONTEND_HEALTH_URL = "http://127.0.0.1:$FRONTEND_PORT"
$MAX_RETRIES = 30
$RETRY_INTERVAL = 2

function Write-Status($msg) { Write-Host "`n[*] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "[-] $msg" -ForegroundColor Red }

function Wait-HealthCheck {
    param([string]$Url, [string]$Label, [int]$Retries = $MAX_RETRIES)

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
    return $false
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Start-Local {
    Write-Status "========== 本地模式启动 =========="

    if (-not (Test-Command "python")) {
        Write-Fail "未找到 python，请先安装 Python 3.12+"
        exit 1
    }
    if (-not (Test-Command "node")) {
        Write-Fail "未找到 node，请先安装 Node.js 20+"
        exit 1
    }

    $backendDir = Join-Path $PSScriptRoot "backend"
    $frontendDir = Join-Path $PSScriptRoot "frontend"
    $venvDir = Join-Path $backendDir ".venv"
    $venvPython = Join-Path $venvDir "Scripts" "python.exe"
    $venvPip = Join-Path $venvDir "Scripts" "pip.exe"

    if (-not (Test-Path $venvDir)) {
        Write-Status "创建 Python 虚拟环境 ..."
        python -m venv $venvDir
        if ($LASTEXITCODE -ne 0) { Write-Fail "创建虚拟环境失败"; exit 1 }
        Write-Ok "虚拟环境已创建"
    }

    Write-Status "安装后端依赖 ..."
    & $venvPip install -r (Join-Path $backendDir "requirements.txt") -q
    if ($LASTEXITCODE -ne 0) { Write-Fail "后端依赖安装失败"; exit 1 }
    Write-Ok "后端依赖已就绪"

    Write-Status "安装前端依赖 ..."
    Push-Location $frontendDir
    npm install --silent 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Fail "前端依赖安装失败"; Pop-Location; exit 1 }
    Pop-Location
    Write-Ok "前端依赖已就绪"

    Write-Status "启动后端服务 ..."
    $backendProc = Start-Process -FilePath $venvPython -ArgumentList "wsgi.py" -WorkingDirectory $backendDir -PassThru -NoNewWindow
    $script:localProcs += $backendProc

    $backendOk = Wait-HealthCheck -Url $BACKEND_HEALTH_URL -Label "后端"
    if (-not $backendOk) {
        Write-Fail "后端启动失败，进程 ID: $($backendProc.Id)，请检查端口 $BACKEND_PORT 是否被占用或查看上方日志"
        Stop-Local
        exit 1
    }

    Write-Status "启动前端服务 ..."
    $frontendProc = Start-Process -FilePath "npm" -ArgumentList "run","dev" -WorkingDirectory $frontendDir -PassThru -NoNewWindow
    $script:localProcs += $frontendProc

    $frontendOk = Wait-HealthCheck -Url $FRONTEND_HEALTH_URL -Label "前端"
    if (-not $frontendOk) {
        Write-Fail "前端启动失败，进程 ID: $($frontendProc.Id)，请检查端口 $FRONTEND_PORT 是否被占用或查看上方日志"
        Stop-Local
        exit 1
    }

    Write-Ok "========== 本地服务已全部就绪 =========="
    Write-Host "`n  后端: http://127.0.0.1:$BACKEND_PORT/api/health" -ForegroundColor White
    Write-Host "  前端: http://127.0.0.1:$FRONTEND_PORT`n" -ForegroundColor White
}

function Stop-Local {
    if ($script:localProcs) {
        Write-Status "停止本地进程 ..."
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
        Write-Fail "未找到 docker，请先安装 Docker Desktop"
        exit 1
    }

    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Docker 守护进程未运行，请先启动 Docker Desktop"
        exit 1
    }
    Write-Ok "Docker 守护进程正常运行"

    if (-not (Test-Command "docker")) {
        Write-Fail "未找到 docker compose 命令"
        exit 1
    }

    Write-Status "构建并启动容器 ..."
    docker compose -f (Join-Path $PSScriptRoot "docker-compose.yml") up --build -d 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "容器启动失败，请查看上方日志"
        exit 1
    }
    Write-Ok "容器已启动"

    $backendOk = Wait-HealthCheck -Url $BACKEND_HEALTH_URL -Label "后端容器"
    if (-not $backendOk) {
        Write-Fail "后端容器健康检查失败"
        Write-Warn "尝试查看日志: docker compose logs backend"
        docker compose -f (Join-Path $PSScriptRoot "docker-compose.yml") logs backend --tail 30
        exit 1
    }

    $frontendOk = Wait-HealthCheck -Url $FRONTEND_HEALTH_URL -Label "前端容器"
    if (-not $frontendOk) {
        Write-Fail "前端容器健康检查失败"
        Write-Warn "尝试查看日志: docker compose logs frontend"
        docker compose -f (Join-Path $PSScriptRoot "docker-compose.yml") logs frontend --tail 30
        exit 1
    }

    Write-Ok "========== Docker 服务已全部就绪 =========="
    Write-Host "`n  后端: http://127.0.0.1:$BACKEND_PORT/api/health" -ForegroundColor White
    Write-Host "  前端: http://127.0.0.1:$FRONTEND_PORT`n" -ForegroundColor White
}

function Stop-Docker {
    Write-Status "停止 Docker 容器 ..."
    docker compose -f (Join-Path $PSScriptRoot "docker-compose.yml") down 2>&1
    Write-Ok "容器已停止"
}

function Show-Help {
    Write-Host @"
驾考科目预约系统 - 统一启动脚本

用法:
  .\start.ps1 <命令>

命令:
  local       本地开发模式启动（自动创建 venv、安装依赖、启动服务）
  docker      Docker Compose 模式启动
  stop-local  停止本地服务
  stop-docker 停止 Docker 容器
  help        显示此帮助信息

示例:
  .\start.ps1 local
  .\start.ps1 docker
  .\start.ps1 stop-local
"@
}

$script:localProcs = @()

try {
    switch ($args[0]) {
        "local"       { Start-Local }
        "docker"      { Start-Docker }
        "stop-local"  { Stop-Local }
        "stop-docker" { Stop-Docker }
        "help"        { Show-Help }
        default       { Show-Help; exit 1 }
    }
} catch {
    Write-Fail "启动过程中发生异常: $_"
    if ($args[0] -eq "local") { Stop-Local }
    exit 1
}
