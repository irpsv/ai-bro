#!/usr/bin/env python3
"""Прогоняет trigger-evals через агентский харнес.

Без имени скилла гоняет все скиллы, у которых есть evals/trigger-evals.json.
С именем — только этот скилл. --agent задаёт харнес, например
cursor:composer-2.5 или codex:ollama:gemma4. Без флага запускается
cursor-agent с моделью по умолчанию.

На время прогона в /tmp собирается каталог с симлинками на все скиллы.
Каждый query запускается один раз. Срабатывание — чтение SKILL.md внутри
этого каталога. Чтение установленной копии плагина не считается.

--verbose печатает в stderr запрос к агенту и строки, полученные от него.
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import dataclass
from pathlib import Path

QUERY_TIMEOUT_SECONDS = 300
_log_lock = threading.Lock()

_RESET = "\033[0m"
_BOLD = "\033[1m"
_DIM = "\033[2m"
_RED = "\033[31m"
_GREEN = "\033[32m"
_YELLOW = "\033[33m"
_BLUE = "\033[34m"
_CYAN = "\033[36m"
_INDENT = "  "

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"


class CursorAgentError(RuntimeError):
    pass


@dataclass(frozen=True)
class AgentSpec:
    harness: str
    model: str | None = None
    provider: str | None = None

    def label(self) -> str:
        if self.provider and self.model:
            return f"{self.harness}:{self.provider}:{self.model}"
        if self.model:
            return f"{self.harness}:{self.model}"
        return self.harness


def parse_agent(value: str) -> AgentSpec:
    parts = [part.strip() for part in value.split(":")]
    if len(parts) >= 2 and parts[0] == "cursor" and all(parts[1:]):
        return AgentSpec("cursor", model=":".join(parts[1:]))
    if (
        len(parts) >= 3
        and parts[0] == "codex"
        and parts[1] in {"ollama", "lmstudio"}
        and all(parts[2:])
    ):
        return AgentSpec("codex", model=":".join(parts[2:]), provider=parts[1])
    raise argparse.ArgumentTypeError(
        "ожидается cursor:<модель> или codex:ollama:<модель>, "
        "например cursor:composer-2.5 или codex:ollama:gemma4"
    )


def link_skills(workspace: Path) -> list[tuple[str, Path]]:
    destination = workspace / ".agents" / "skills"
    destination.mkdir(parents=True)
    linked: list[tuple[str, Path]] = []
    for skill_dir in sorted(path for path in SKILLS_DIR.iterdir() if path.is_dir()):
        target = skill_dir.resolve()
        if not target.is_absolute():
            raise RuntimeError(f"цель симлинка не абсолютна: {target}")
        (destination / skill_dir.name).symlink_to(target)
        linked.append((skill_dir.name, target))
    return linked


def skill_name_from_read_path(path: str, workspace: Path) -> str | None:
    """Имя скилла, если path указывает на SKILL.md внутри каталога прогона.

    Сравнивается каталог `.agents/skills`, без разыменования симлинка скилла:
    цель симлинка лежит в репозитории, а установленная копия плагина — в другом
    дереве. Оба этих пути не входят в прогон.
    """
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = workspace / candidate
    candidate = Path(os.path.normpath(candidate))
    if candidate.name != "SKILL.md":
        return None

    skill_dir = candidate.parent
    name = skill_dir.name
    if name in {"", ".", ".."}:
        return None

    try:
        skills_root = (workspace / ".agents" / "skills").resolve()
        if skill_dir.parent.resolve() != skills_root:
            return None
    except OSError:
        return None
    return name


def _loads_object(line: str) -> dict | None:
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        return None
    if not isinstance(event, dict):
        return None
    return event


def skill_read_from_event(line: str, workspace: Path) -> str | None:
    event = _loads_object(line)
    if event is None or event.get("type") != "tool_call":
        return None
    tool_call = event.get("tool_call")
    if not isinstance(tool_call, dict):
        return None
    read_call = tool_call.get("readToolCall")
    if not isinstance(read_call, dict):
        return None
    args = read_call.get("args")
    if not isinstance(args, dict):
        return None
    path = args.get("path")
    if not isinstance(path, str) or path == "":
        return None
    return skill_name_from_read_path(path, workspace)


def _assert_under_tmp(workspace: Path) -> None:
    resolved = workspace.resolve()
    tmp_root = Path("/tmp").resolve()
    if resolved != tmp_root and tmp_root not in resolved.parents:
        raise RuntimeError(f"каталог прогона должен быть внутри /tmp, получен {resolved}")


def _remove_workspace(workspace: Path) -> None:
    if not workspace.exists() and not workspace.is_symlink():
        return
    _assert_under_tmp(workspace)
    shutil.rmtree(workspace)


def _signal_group(proc: subprocess.Popen[str], sig: int) -> None:
    try:
        os.killpg(proc.pid, sig)
    except ProcessLookupError:
        return
    except PermissionError:
        try:
            proc.send_signal(sig)
        except (ProcessLookupError, OSError):
            return


def _terminate(proc: subprocess.Popen[str]) -> None:
    if proc.poll() is not None:
        return
    for sig, timeout in ((signal.SIGTERM, 3), (signal.SIGKILL, 5)):
        _signal_group(proc, sig)
        try:
            proc.wait(timeout=timeout)
            return
        except subprocess.TimeoutExpired:
            continue


def _use_color(stream) -> bool:
    if os.environ.get("NO_COLOR") is not None:
        return False
    if os.environ.get("FORCE_COLOR"):
        return True
    isatty = getattr(stream, "isatty", None)
    return bool(isatty and isatty())


def _paint(text: str, code: str, stream) -> str:
    if not _use_color(stream):
        return text
    return f"{code}{text}{_RESET}"


def _log(text: str) -> None:
    with _log_lock:
        print(text, file=sys.stderr, flush=True)


def _log_channel(label: str, body: str, code: str) -> None:
    painted_label = _paint(label, _BOLD + code, stream=sys.stderr)
    painted_body = _paint(body, _DIM, stream=sys.stderr)
    _log(f"{_INDENT}{painted_label} {painted_body}")


def _drain_text(stream, sink: list[str], *, verbose: bool) -> None:
    for line in stream:
        sink.append(line)
        if verbose:
            _log_channel("получено stderr:", line.rstrip("\n"), _YELLOW)
        if sum(len(item) for item in sink) > 8192:
            del sink[:-20]


def cursor_command(workspace: Path, query: str, model: str | None) -> list[str]:
    command = [
        "cursor-agent",
        "-p",
        "--output-format",
        "stream-json",
        "--trust",
        "--mode",
        "ask",
        "--sandbox",
        "enabled",
        "--workspace",
        str(workspace),
    ]
    if model:
        command.extend(["--model", model])
    command.append(query)
    return command


def _ollama_openai_base_url() -> str:
    host = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").strip().rstrip("/")
    if not host.startswith(("http://", "https://")):
        host = "http://" + host
    if host.endswith("/v1"):
        return host + "/"
    return host + "/v1/"


def _write_ollama_catalog(workspace: Path, model: str) -> Path:
    catalog = workspace / "ollama-model.json"
    catalog.write_text(
        json.dumps(
            {
                "models": [
                    {
                        "base_instructions": "",
                        "context_window": 131072,
                        "default_reasoning_level": "high",
                        "default_verbosity": "low",
                        "display_name": model,
                        "experimental_supported_tools": [],
                        "input_modalities": ["text"],
                        "priority": 0,
                        "shell_type": "default",
                        "slug": model,
                        "support_verbosity": True,
                        "supported_in_api": True,
                        "supported_reasoning_levels": [
                            {
                                "description": "Turn thinking off",
                                "effort": "none",
                            },
                            {
                                "description": "Greater thinking depth for complex tasks",
                                "effort": "high",
                            },
                        ],
                        "supports_parallel_tool_calls": False,
                        "supports_reasoning_summaries": False,
                        "truncation_policy": {"limit": 10000, "mode": "bytes"},
                        "visibility": "list",
                    }
                ]
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    return catalog


def codex_command(workspace: Path, query: str, agent: AgentSpec) -> list[str]:
    command = [
        "codex",
        "exec",
        "--json",
        "--color",
        "never",
        "-s",
        "read-only",
        "--skip-git-repo-check",
        "-C",
        str(workspace),
    ]
    if agent.provider == "ollama":
        catalog = _write_ollama_catalog(workspace, agent.model or "")
        command.extend(
            [
                "-c",
                'model_provider="ollama_local"',
                "-c",
                'model_providers.ollama_local.name="Ollama"',
                "-c",
                f"model_providers.ollama_local.base_url={json.dumps(_ollama_openai_base_url())}",
                "-c",
                'model_providers.ollama_local.wire_api="responses"',
                "-c",
                f"model_catalog_json={json.dumps(str(catalog))}",
                "-m",
                agent.model or "",
            ]
        )
    else:
        command.extend(
            [
                "--oss",
                "--local-provider",
                agent.provider or "",
                "-m",
                agent.model or "",
            ]
        )
    command.append(query)
    return command


def _skill_mentioned_as_path(text: str, workspace: Path) -> str | None:
    if "SKILL.md" not in text:
        return None
    skill = skill_name_from_read_path(text.strip().strip("\"'`"), workspace)
    if skill:
        return skill
    marker = "SKILL.md"
    start = 0
    while True:
        index = text.find(marker, start)
        if index == -1:
            return None
        end = index + len(marker)
        begin = index
        while begin > 0 and text[begin - 1] not in " \t\n\r\"'`|&;<>()":
            begin -= 1
        token = text[begin:end].strip("\"'`")
        skill = skill_name_from_read_path(token, workspace)
        if skill:
            return skill
        start = end


def _skill_in_json_value(value: object, workspace: Path) -> str | None:
    if isinstance(value, str):
        if value[:1] in "{[":
            try:
                parsed = json.loads(value)
            except json.JSONDecodeError:
                parsed = None
            if parsed is not None:
                return _skill_in_json_value(parsed, workspace)
        return _skill_mentioned_as_path(value, workspace)
    if isinstance(value, dict):
        for item in value.values():
            skill = _skill_in_json_value(item, workspace)
            if skill:
                return skill
        return None
    if isinstance(value, list):
        for item in value:
            skill = _skill_in_json_value(item, workspace)
            if skill:
                return skill
    return None


def skill_from_codex_event(line: str, workspace: Path) -> str | None:
    event = _loads_object(line)
    if not isinstance(event, dict):
        return None
    item = event.get("item")
    if not isinstance(item, dict):
        return None
    if item.get("type") == "command_execution":
        command = item.get("command")
        if isinstance(command, list):
            command = " ".join(str(part) for part in command)
        if isinstance(command, str):
            return _skill_mentioned_as_path(command, workspace)
        return None
    for key in ("arguments", "args", "input", "parameters"):
        skill = _skill_in_json_value(item.get(key), workspace)
        if skill:
            return skill
    return None


def query_triggers_target(
    workspace: Path,
    query: str,
    target_skill: str,
    agent: AgentSpec,
    *,
    verbose: bool = False,
) -> bool:
    if agent.harness == "codex":
        command = codex_command(workspace, query, agent)
        read_skill = skill_from_codex_event
        empty_message = "codex не вернул json"
    else:
        command = cursor_command(workspace, query, agent.model)
        read_skill = skill_read_from_event
        empty_message = "cursor-agent не вернул stream-json"
    if verbose:
        _log_channel("отправлено:", shlex.join(command), _CYAN)
    proc = subprocess.Popen(
        command,
        cwd=workspace,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
        start_new_session=True,
    )
    lines: queue.Queue[str | None] = queue.Queue()
    stderr_lines: list[str] = []

    def read_stdout() -> None:
        assert proc.stdout is not None
        try:
            for line in proc.stdout:
                lines.put(line)
        finally:
            lines.put(None)

    stdout_thread = threading.Thread(target=read_stdout, daemon=True)
    stderr_thread = threading.Thread(
        target=_drain_text,
        args=(proc.stderr, stderr_lines),
        kwargs={"verbose": verbose},
        daemon=True,
    )
    stdout_thread.start()
    stderr_thread.start()

    triggered = False
    saw_json = False
    deadline = time.monotonic() + QUERY_TIMEOUT_SECONDS
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            try:
                line = lines.get(timeout=remaining)
            except queue.Empty:
                break
            if line is None:
                break
            if verbose:
                _log_channel("получено:", line.rstrip("\n"), _BLUE)
            if _loads_object(line) is not None:
                saw_json = True
            skill = read_skill(line, workspace)
            if skill is None:
                continue
            triggered = skill == target_skill
            break
    finally:
        _terminate(proc)
        stderr_thread.join(timeout=2)

    if not saw_json:
        detail = "".join(stderr_lines).strip()
        message = empty_message
        if detail:
            message = f"{message}: {detail}"
        raise CursorAgentError(message)
    return triggered


def evals_path(skill: str) -> Path:
    return SKILLS_DIR / skill / "evals" / "trigger-evals.json"


def skills_with_evals() -> list[str]:
    names: list[str] = []
    for skill_dir in sorted(path for path in SKILLS_DIR.iterdir() if path.is_dir()):
        if evals_path(skill_dir.name).is_file():
            names.append(skill_dir.name)
    return names


def select_skills(name: str | None) -> list[str]:
    found = skills_with_evals()
    if name is None:
        if not found:
            raise CursorAgentError("нет скиллов с trigger-evals.json")
        return found
    if not (SKILLS_DIR / name).is_dir():
        known = ", ".join(
            path.name for path in sorted(SKILLS_DIR.iterdir()) if path.is_dir()
        )
        raise CursorAgentError(f"скилл не найден: {name}. Доступны: {known}")
    if name not in found:
        raise CursorAgentError(f"у скилла {name} нет evals/trigger-evals.json")
    return [name]


def load_cases(skill: str) -> list[dict]:
    path = evals_path(skill)
    if not path.is_file():
        raise CursorAgentError(f"не найден файл eval: {path}")
    cases = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(cases, list) or not cases:
        raise CursorAgentError(f"{skill}: trigger-evals.json ожидался непустой список")
    for index, case in enumerate(cases, start=1):
        if not isinstance(case, dict):
            raise CursorAgentError(f"{skill}: некорректная запись eval #{index}")
        query = case.get("query")
        should_trigger = case.get("should_trigger")
        if not isinstance(query, str) or query == "" or not isinstance(should_trigger, bool):
            raise CursorAgentError(f"{skill}: некорректная запись eval #{index}")
    return cases


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Прогоняет trigger-evals через агентский харнес. "
            "Без имени скилла гоняет все скиллы с evals/trigger-evals.json."
        )
    )
    parser.add_argument(
        "skill",
        nargs="?",
        help="имя скилла; без аргумента прогоняются все скиллы с trigger-evals.json",
    )
    parser.add_argument(
        "--agent",
        type=parse_agent,
        default=AgentSpec("cursor"),
        help="cursor:<модель> или codex:ollama:<модель>, "
        "например cursor:composer-2.5 или codex:ollama:gemma4. "
        "Без флага — cursor с моделью по умолчанию",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="показать в stderr запрос к агенту и полученный от него поток",
    )
    return parser.parse_args(argv)


def _print_error(message: str) -> None:
    print(_paint(message, _BOLD + _RED, stream=sys.stderr), file=sys.stderr, flush=True)


def _print_setup(workspace: Path, links: list[tuple[str, Path]], agent: AgentSpec) -> None:
    agent_label = _paint("Агент", _BOLD, stream=sys.stderr)
    agent_value = _paint(agent.label(), _CYAN, stream=sys.stderr)
    print(f"{agent_label} {agent_value}", file=sys.stderr, flush=True)
    label = _paint("Создана временная папка", _BOLD, stream=sys.stderr)
    folder = _paint(str(workspace), _CYAN, stream=sys.stderr)
    print(f"{label} {folder}", file=sys.stderr, flush=True)
    print(
        _paint("Созданы симлинки:", _BOLD, stream=sys.stderr),
        file=sys.stderr,
        flush=True,
    )
    for name, target in links:
        line = _paint(f"{_INDENT}{name} -> {target}", _DIM, stream=sys.stderr)
        print(line, file=sys.stderr, flush=True)


def _print_skill_header(name: str) -> None:
    print(file=sys.stderr, flush=True)
    print(file=sys.stderr, flush=True)
    print(_paint(name, _BOLD + _CYAN, stream=sys.stderr), file=sys.stderr, flush=True)
    print(file=sys.stderr, flush=True)


def _print_case_header(index: int, total: int, query: str) -> None:
    if index > 1:
        print(file=sys.stderr, flush=True)
    width = len(str(total))
    counter = _paint(f"[{index:>{width}}/{total}]", _BOLD + _CYAN, stream=sys.stderr)
    title = _paint(query, _BOLD, stream=sys.stderr)
    print(f"{counter} {title}", file=sys.stderr, flush=True)


def _print_status(ok: bool) -> None:
    if ok:
        label = _paint("SUCCESS", _BOLD + _GREEN, stream=sys.stdout)
    else:
        label = _paint("FAIL", _BOLD + _RED, stream=sys.stdout)
    print(f"{_INDENT}{label}", flush=True)


def _print_summary(passed: int, total: int) -> None:
    if passed == total:
        code = _BOLD + _GREEN
    elif passed == 0:
        code = _BOLD + _RED
    else:
        code = _BOLD + _YELLOW
    print(flush=True)
    print(_paint(f"{passed}/{total}", code, stream=sys.stdout), flush=True)


def _ensure_harness(agent: AgentSpec) -> None:
    if agent.harness == "cursor":
        if shutil.which("cursor-agent") is None:
            raise CursorAgentError("Не найден cursor-agent в PATH")
        return
    if shutil.which("codex") is None:
        raise CursorAgentError("Не найден codex в PATH")
    if agent.provider == "ollama" and shutil.which("ollama") is None:
        raise CursorAgentError("Не найден ollama в PATH")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        _ensure_harness(args.agent)
        selected = [(skill, load_cases(skill)) for skill in select_skills(args.skill)]
    except (OSError, json.JSONDecodeError, CursorAgentError) as error:
        _print_error(str(error))
        return 2

    workspace = Path(tempfile.mkdtemp(prefix="trigger-evals-", dir="/tmp"))
    passed = 0
    total_cases = 0
    try:
        _assert_under_tmp(workspace)
        links = link_skills(workspace)
        _print_setup(workspace, links, args.agent)
        for skill, cases in selected:
            _print_skill_header(skill)
            skill_passed = 0
            for index, case in enumerate(cases, start=1):
                query = case["query"]
                _print_case_header(index, len(cases), query)
                try:
                    triggered = query_triggers_target(
                        workspace,
                        query,
                        skill,
                        args.agent,
                        verbose=args.verbose,
                    )
                except CursorAgentError as error:
                    _print_error(str(error))
                    return 2
                ok = triggered == case["should_trigger"]
                if ok:
                    skill_passed += 1
                _print_status(ok)
            _print_summary(skill_passed, len(cases))
            passed += skill_passed
            total_cases += len(cases)
    finally:
        _remove_workspace(workspace)

    if len(selected) > 1:
        _print_summary(passed, total_cases)
    return 0 if passed == total_cases else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
