"""Offline tests: synthetic identities only; never read a real Keychain or connect."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "build/SSH Launch.app/Contents/MacOS/SSHLaunch"
CORE = ROOT / "build/core-tests"


def core(*args):
    result = subprocess.run([str(CORE), *map(str, args)], capture_output=True, text=True, check=True, timeout=10)
    return json.loads(result.stdout)


class CoreTests(unittest.TestCase):
    def terminal(self, alias, folder):
        script = subprocess.check_output([str(APP), "--print-terminal-script", alias, folder], text=True)
        subprocess.run(["/bin/sh", "-n"], input=script, text=True, check=True)
        words = shlex.split(script.splitlines()[-1])
        self.assertEqual(words[:7], ["exec", "/usr/bin/ssh", "-t", "-o", "ConnectTimeout=20", "--", alias])
        self.assertEqual(len(words), 8)
        return words[-1]

    def test_remote_folder_quoting(self):
        with tempfile.TemporaryDirectory() as directory:
            special = "quotes' spaces; $(echo BAD) & " + chr(96) + "echo BAD" + chr(96)
            target = Path(directory, special)
            target.mkdir()
            for folder in [str(target), "~/" + special, "~"]:
                command = self.terminal("demo", folder)
                suffix = 'exec "${SHELL:-/bin/sh}" -i'
                self.assertTrue(command.endswith(suffix))
                probe = command.removesuffix(suffix) + "pwd -P"
                output = subprocess.check_output(["/bin/sh", "-c", probe], env=dict(os.environ, HOME=directory), text=True)
                self.assertEqual(output.strip(), str(Path(directory if folder == "~" else target).resolve()))

    def test_missing_folder_stops(self):
        command = self.terminal("demo", "/nonexistent/ssh-launch-test-missing")
        probe = command.removesuffix('exec "${SHELL:-/bin/sh}" -i') + "printf SHOULD_NOT_RUN"
        result = subprocess.run(["/bin/sh", "-c", probe], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("SHOULD_NOT_RUN", result.stdout)

    def test_rejects_option_injection_and_control_characters(self):
        for alias, folder in [("-oProxyCommand=bad", "/tmp"), ("bad name", "/tmp"),
                              ("demo;echo", "/tmp"), ("demo", ""), ("demo", "/tmp\nbad"),
                              ("demo", "relative"), ("demo", "~someone/project")]:
            with self.subTest(alias=alias, folder=folder):
                self.assertNotEqual(subprocess.run([str(APP), "--print-terminal-script", alias, folder],
                                                  capture_output=True).returncode, 0)

    def test_ssh_includes_quotes_cycles_and_wildcards(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            (root / "parts").mkdir()
            (root / "config").write_text('Include "parts/*.conf"\nHost main alias2 # comment\nHost * !blocked wildcard?\n')
            (root / "parts/a.conf").write_text('Host="jump"\nInclude config\nHost = quoted\n')
            self.assertEqual(core("hosts", root / "config"), ["jump", "quoted", "main", "alias2"])

    def test_malformed_and_missing_history(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root)
            for name, data in [("bad", "[]"), ("broken", "{"), ("local", '{"folder":"file:///tmp"}')]:
                (path / name).mkdir()
                (path / name / "workspace.json").write_text(data)
            self.assertEqual(core("recent", "demo", root), [])
            self.assertEqual(core("hosts", path / "missing"), [])

    def test_recent_folders_are_alias_scoped_and_deduplicated(self):
        with tempfile.TemporaryDirectory() as root:
            for i, uri in enumerate(["vscode-remote://ssh-remote+demo/home/example/a%20b",
                                     "vscode-remote://ssh-remote+demo/home/example/a%20b",
                                     "vscode-remote://ssh-remote+other/private/path"]):
                path = Path(root, str(i)); path.mkdir()
                (path / "workspace.json").write_text(json.dumps({"folder": uri}))
            self.assertEqual(core("recent", "demo", root), ["/home/example/a b"])

    def test_credentials_isolated_by_alias_host_user_port_and_route(self):
        identities = []
        base = ["demo", "server.example.com", "developer", "22", "none"]
        identities.append(core("credential", *base)[0])
        for index, new in enumerate(["other", "other.example.com", "another", "2222", "bastion"]):
            changed = base.copy(); changed[index] = new
            identities.append(core("credential", *changed)[0])
        self.assertEqual(len(set(identities)), 6)
        self.assertEqual(identities[0], core("credential", *base)[0])

    def test_password_prompt_never_matches_mfa_key_or_other_host(self):
        for prompt in ["Password:", "Verification code:", "One-time password:",
                       "Enter passphrase for key '/tmp/example':", "developer@bastion.example.com's password:"]:
            self.assertEqual(core("prompt", prompt, "server.example.com", "developer"), [False])
        self.assertEqual(core("prompt", "developer@server.example.com's password: ",
                              "server.example.com", "developer"), [True])

    def test_config_setup_is_scoped_idempotent_and_backed_up(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            original = "ServerAliveInterval 30\nHost demo\n  HostName server.example.com\n  User developer\nHost untouched\n  Port 2222\n"
            (root / "config").write_text(original)
            for _ in range(2):
                subprocess.run([str(CORE), "configure", "demo", str(root)], check=True)
            config = (root / "config").read_text()
            self.assertEqual(config, "Include ~/.ssh/ssh-launch.conf\nHost *\n" + original)
            self.assertEqual((root / "ssh-launch.conf").read_text().count("Host demo\n"), 1)
            backups = list(root.glob("config.ssh-launch-backup-*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), original)
            self.assertEqual((root / "ssh-launch.conf").stat().st_mode & 0o777, 0o600)
            # Make the fixture Include absolute so ssh -F reads only synthetic files.
            config = config.replace("~/.ssh/ssh-launch.conf", str(root / "ssh-launch.conf"))
            (root / "fixture").write_text(config)
            for alias in ["demo", "untouched"]:
                output = subprocess.check_output(["ssh", "-F", str(root / "fixture"), "-G", alias],
                                                 stderr=subprocess.DEVNULL, text=True)
                values = dict(line.split(" ", 1) for line in output.splitlines())
                self.assertEqual(values["serveraliveinterval"], "30")
                self.assertEqual(values["controlmaster"], "auto" if alias == "demo" else "false")
                if alias == "untouched": self.assertEqual(values["port"], "2222")

    def test_config_refuses_symlink(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root)
            (path / "original").write_text("Host demo\n")
            (path / "config").symlink_to(path / "original")
            result = subprocess.run([str(CORE), "configure", "demo", root])
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((path / "original").read_text(), "Host demo\n")

    def test_non_top_level_existing_include_is_not_silently_moved(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root)
            original = "Host demo\n Include ~/.ssh/ssh-launch.conf\n"
            (path / "config").write_text(original)
            self.assertNotEqual(subprocess.run([str(CORE), "configure", "demo", root]).returncode, 0)
            self.assertEqual((path / "config").read_text(), original)

    def test_process_capture_and_deadline(self):
        self.assertEqual(core("run", "printf hello"), {"status": 0, "output": "hello"})
        start = time.monotonic()
        self.assertEqual(core("run", "sleep 3")["status"], 124)
        self.assertLess(time.monotonic() - start, 2)

    def test_background_child_does_not_hold_capture_open(self):
        start = time.monotonic()
        result = core("run", "sleep 2 & printf ready")
        self.assertEqual(result, {"status": 0, "output": "ready"})
        self.assertLess(time.monotonic() - start, 1.5)


if __name__ == "__main__":
    unittest.main()
