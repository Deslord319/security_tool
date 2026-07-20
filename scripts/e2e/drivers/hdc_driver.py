from __future__ import annotations

from pathlib import Path

from scripts.e2e.core.utils import run_command


class HdcDriver:
    def __init__(self, project_root: Path, device_id: str | None, dry_run: bool):
        self.project_root = project_root
        self.device_id = device_id
        self.dry_run = dry_run

    def detect_single_device(self) -> str | None:
        result = run_command(["hdc", "list", "targets"], self.project_root, 10, False)
        if result.returncode != 0:
            return None
        lines = [line.strip() for line in result.stdout.splitlines() if line.strip() and line.strip() != "[Empty]"]
        if len(lines) == 1:
            return lines[0]
        return None

    def command(self, args: list[str]) -> list[str]:
        command = ["hdc"]
        if self.device_id:
            command.extend(["-t", self.device_id])
        command.extend(args)
        return command

    def run(self, args: list[str], timeout_sec: int = 20):
        return run_command(self.command(args), self.project_root, timeout_sec, self.dry_run)

    def shell(self, shell_command: str, timeout_sec: int = 20):
        return run_command(self.command(["shell", shell_command]), self.project_root, timeout_sec, self.dry_run)

    def wake_device(self, timeout_sec: int = 10):
        return self.shell("power-shell wakeup", timeout_sec)

    def enable_admin(
        self,
        *,
        bundle_name: str,
        ability_name: str,
        admin_type: str = "super",
        timeout_sec: int = 20,
    ):
        command_text = f"edm enable-admin -n {bundle_name} -a {ability_name} -t {admin_type}"
        return self.shell(command_text, timeout_sec)
