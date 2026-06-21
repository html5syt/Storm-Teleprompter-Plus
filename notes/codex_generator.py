#!/usr/bin/env python3
"""
generate_codex_headers.py

根据当前文件夹下的 Git 仓库信息和 Codex 客户端规范，生成完整的 HTTP 请求头列表。
支持自动检测操作系统、持久化安装 ID、读取 Beta 功能配置等。
"""

import os
import sys
import json
import uuid
import platform
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Optional

# ---------- 配置常量 ----------
CODEX_INSTALLATION_FILE = Path.home() / ".codex" / "installation_id"
CODEX_BETA_FEATURES_ENV = "CODEX_BETA_FEATURES"   # 逗号分隔，如 "remote_compaction_v2"
CODEX_TURN_STATE_FILE = Path.home() / ".codex" / "turn_state"   # 可存储服务端返回的 turn state
CODEX_SUBAGENT_ENV = "CODEX_SUBAGENT"            # 设置子代理类型
CODEX_MEMGEN_ENV = "CODEX_MEMGEN_REQUEST"        # 设为 "true" 启用内存生成

# ---------- 工具函数 ----------
def get_os_info() -> str:
    """返回格式化的 OS 信息，用于 user-agent。"""
    system = platform.system()
    release = platform.release()
    machine = platform.machine()
    # 映射常见架构
    arch_map = {
        "AMD64": "x86_64",
        "x86_64": "x86_64",
        "arm64": "aarch64",
        "aarch64": "aarch64",
    }
    arch = arch_map.get(machine, machine)
    # 特殊处理 Windows
    if system == "Windows":
        return f"Windows {release}; {arch}"
    elif system == "Darwin":
        return f"Mac OS {release}; {arch}"
    else:
        return f"{system} {release}; {arch}"

def get_codex_version() -> str:
    """获取 Codex CLI 版本，默认 0.44.0（可自定义）。"""
    # 可以从环境变量或配置文件读取
    return os.environ.get("CODEX_CLI_VERSION", "0.44.0")

def get_installation_id() -> str:
    """获取或生成持久化的 installation_id。"""
    if CODEX_INSTALLATION_FILE.exists():
        try:
            with open(CODEX_INSTALLATION_FILE, "r") as f:
                return f.read().strip()
        except:
            pass
    # 不存在或读取失败则生成新 UUID
    new_id = str(uuid.uuid4())
    CODEX_INSTALLATION_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CODEX_INSTALLATION_FILE, "w") as f:
        f.write(new_id)
    return new_id

def get_turn_state() -> str:
    """获取上次服务端返回的 turn_state（用于粘性路由）。"""
    if CODEX_TURN_STATE_FILE.exists():
        try:
            with open(CODEX_TURN_STATE_FILE, "r") as f:
                return f.read().strip()
        except:
            pass
    return ""   # 首次请求为空

def get_beta_features() -> str:
    """从环境变量获取 beta 功能列表（逗号分隔）。"""
    return os.environ.get(CODEX_BETA_FEATURES_ENV, "")

def get_subagent() -> str:
    """获取子代理类型。"""
    return os.environ.get(CODEX_SUBAGENT_ENV, "")

def get_memgen_request() -> str:
    """是否启用内存生成请求。"""
    return os.environ.get(CODEX_MEMGEN_ENV, "").lower() == "true"

def run_git_command(args: list) -> Optional[str]:
    """执行 Git 命令并返回输出。"""
    try:
        result = subprocess.run(
            ['git'] + args,
            capture_output=True,
            text=True,
            check=True,
            cwd=os.getcwd()
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

def get_git_info() -> Dict:
    """获取当前 Git 仓库信息。"""
    info = {
        'remote_url': None,
        'commit_hash': None,
        'has_changes': False,
        'branch': None,
    }
    remote_url = run_git_command(['remote', 'get-url', 'origin'])
    if remote_url:
        info['remote_url'] = remote_url
    commit_hash = run_git_command(['rev-parse', 'HEAD'])
    if commit_hash:
        info['commit_hash'] = commit_hash
    status = run_git_command(['status', '--porcelain'])
    if status is not None and status != '':
        info['has_changes'] = True
    branch = run_git_command(['branch', '--show-current'])
    if branch:
        info['branch'] = branch
    return info

def generate_codex_headers() -> Dict[str, str]:
    """生成完整的 Codex 请求头字典。"""
    headers = {}

    # 1. 基础头
    headers['accept'] = 'text/event-stream'
    headers['content-type'] = 'application/json'
    # user-agent 格式: codex_cli/版本号 (OS 类型 版本; 架构)
    version = get_codex_version()
    os_info = get_os_info()
    headers['user-agent'] = f"codex_cli/{version} ({os_info})"

    # 2. OpenAI Beta 头（固定）
    headers['OpenAI-Beta'] = 'responses_websockets = 2026-02-06'

    # 3. 认证头（从环境变量读取）
    api_key = os.environ.get('CODEX_API_KEY')
    if api_key:
        headers['authorization'] = f'Bearer {api_key}'
    else:
        print("⚠️  警告: 未设置 CODEX_API_KEY 环境变量，将使用占位符。")
        headers['authorization'] = 'Bearer <YOUR_API_KEY>'

    # 4. Codex 特定头
    headers['x-codex-installation-id'] = get_installation_id()

    turn_state = get_turn_state()
    if turn_state:
        headers['x-codex-turn-state'] = turn_state

    beta_features = get_beta_features()
    if beta_features:
        headers['x-codex-beta-features'] = beta_features

    # 5. OpenAI 内部头（按需）
    headers['x-openai-internal-codex-responses-lite'] = 'true'

    subagent = get_subagent()
    if subagent:
        headers['x-openai-subagent'] = subagent

    if get_memgen_request():
        headers['x-openai-memgen-request'] = 'true'

    # 6. 会话 / 线程 / Turn 元数据（参考之前实现）
    import uuid
    session_id = str(uuid.uuid4())
    thread_id = str(uuid.uuid4())
    turn_id = str(uuid.uuid4())

    headers['x-codex-session-id'] = session_id
    headers['x-codex-thread-id'] = thread_id
    headers['x-codex-turn-id'] = turn_id
    headers['x-codex-window-id'] = f"{session_id}:0"
    headers['x-client-request-id'] = session_id
    headers['originator'] = 'codex-tui'

    # 7. Workspace 信息（Git 元数据）
    git_info = get_git_info()
    workspace_info = {}
    if git_info['remote_url'] and git_info['commit_hash']:
        workspace_info[os.getcwd()] = {
            'associated_remote_urls': {
                'origin': git_info['remote_url']
            },
            'latest_git_commit_hash': git_info['commit_hash'],
            'has_changes': git_info['has_changes']
        }
    headers['x-codex-workspaces'] = json.dumps(workspace_info)

    # 8. Turn Metadata（包含完整上下文）
    turn_metadata = {
        "installation_id": get_installation_id(),
        "session_id": session_id,
        "thread_id": thread_id,
        "turn_id": turn_id,
        "window_id": f"{session_id}:0",
        "request_kind": "turn",
        "sandbox": "none",
        "workspaces": workspace_info,
        "turn_started_at_unix_ms": int(datetime.now(timezone.utc).timestamp() * 1000)
    }
    headers['x-codex-turn-metadata'] = json.dumps(turn_metadata)

    return headers

def print_headers(headers: Dict[str, str]) -> None:
    """格式化打印头列表。"""
    print("=" * 70)
    print("📋 Codex 风格请求头列表")
    print("=" * 70)
    for key, value in headers.items():
        if key in ('x-codex-workspaces', 'x-codex-turn-metadata'):
            try:
                parsed = json.loads(value)
                formatted = json.dumps(parsed, indent=2, ensure_ascii=False)
                print(f"{key}:")
                print(formatted)
                print("-" * 50)
                continue
            except:
                pass
        print(f"{key}: {value}")
    print("=" * 70)

def main():
    print("🔍 正在扫描当前 Git 仓库...")
    git_info = get_git_info()
    if git_info['remote_url']:
        print(f"   ✅ 仓库: {git_info['remote_url']}")
        print(f"   📌 Commit: {git_info['commit_hash'][:8] if git_info['commit_hash'] else 'N/A'}")
        print(f"   🌿 分支: {git_info['branch'] or 'N/A'}")
        print(f"   📝 有更改: {'是' if git_info['has_changes'] else '否'}")
    else:
        print("   ⚠️  当前目录不是 Git 仓库或无法获取远程 URL。")

    headers = generate_codex_headers()
    print("\n")
    print_headers(headers)

    # 导出简化的 curl 命令（仅显示部分头）
    print("\n🐱 等价的 curl 命令 (部分):")
    curl_cmd = "curl -X POST <YOUR_ENDPOINT> \\\n"
    for key, value in headers.items():
        if key in ('x-codex-workspaces', 'x-codex-turn-metadata'):
            continue   # 避免过长
        # 转义单引号
        escaped_value = value.replace("'", "'\\''")
        curl_cmd += f"  -H '{key}: {escaped_value}' \\\n"
    curl_cmd += "  -d '{}'"
    print(curl_cmd)

    # 提示持久化 turn_state
    print("\n💡 提示：")
    print(f"   - 安装 ID 已保存至 {CODEX_INSTALLATION_FILE}")
    print(f"   - 如需设置 turn_state，请将其写入 {CODEX_TURN_STATE_FILE}")
    print(f"   - Beta 功能可通过环境变量 {CODEX_BETA_FEATURES_ENV} 设置")
    print(f"   - 子代理类型可通过环境变量 {CODEX_SUBAGENT_ENV} 设置")
    print(f"   - 内存生成请求通过 {CODEX_MEMGEN_ENV}=true 启用")

if __name__ == "__main__":
    main()