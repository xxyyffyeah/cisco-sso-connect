"""Check the public source allowlist; report paths/line numbers, never matched values."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TOP = {"README.md", "README.zh-CN.md", "LICENSE", "SECURITY.md", "AGENTS.md", "CLAUDE.md", ".gitignore"}
DIRECTORIES = {"src", "scripts", "tests", "docs", "examples", ".github"}
SUFFIXES = {".m", ".h", ".plist", ".sh", ".py", ".md", ".yml", ".yaml"}
PATTERNS = {
    "private-key": re.compile(r"-----BEGIN (?:OPENSSH|RSA|EC|DSA|ENCRYPTED) PRIVATE KEY-----"),
    "github-token": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})"),
    "cloud-access-key": re.compile(r"\bAKIA[A-Z0-9]{16}\b"),
    "personal-mac-path": re.compile(r"/Users/[A-Za-z0-9_.-]+/"),
    "literal-password": re.compile(r'(?i)(?:password|passwd|token|api_key)\s*=\s*[@]?"[^"\n]{8,}"'),
}


def paths():
    # If staged/tracked files exist, audit precisely the intended distribution.
    result = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True)
    if result.returncode == 0 and result.stdout:
        return [ROOT / p.decode() for p in result.stdout.split(b"\0") if p]
    return [p for p in ROOT.rglob("*") if p.is_file() and
            not any(part in {"build", "dist", ".git", ".local", "__pycache__"} for part in p.relative_to(ROOT).parts)]


def main():
    problems = []
    files = paths()
    for path in files:
        relative = path.relative_to(ROOT)
        if path.is_symlink():
            problems.append((relative, "symlink")); continue
        allowed = str(relative) in TOP or (
            relative.parts[0] in DIRECTORIES and (path.suffix in SUFFIXES or str(relative) == "examples/ssh-config"))
        if not allowed:
            problems.append((relative, "not-in-source-allowlist")); continue
        try:
            text = path.read_text()
        except (UnicodeError, OSError):
            problems.append((relative, "non-text-or-unreadable")); continue
        for label, pattern in PATTERNS.items():
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                problems.append((relative, f"{label} at line {line}"))
    for path, reason in problems:
        print(f"{path}: {reason}", file=sys.stderr)
    if problems:
        return 1
    print(f"Public-file audit passed: {len(files)} text files. Run a separate secret scanner before publishing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
