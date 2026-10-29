"""Create an allowlisted source bundle in dist/, excluding local/private data."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = {"README.md", "LICENSE", "NOTICE.md", ".gitignore", "CHANGELOG.md",
              "CONTRIBUTING.md", "requirements.txt", "pyproject.toml"}
FOLDERS = {"src", "docs", "tests", "examples", "scripts", "config", "data", ".github"}
EXCLUDED = {"__pycache__", "private", ".local", ".venv"}


def build():
    dest = ROOT / "dist/travel-reimbursement-assistant-0.1.0.zip"
    dest.parent.mkdir(exist_ok=True)
    with ZipFile(dest, "w", ZIP_DEFLATED) as archive:
        for path in sorted(ROOT.rglob("*")):
            rel = path.relative_to(ROOT)
            if not path.is_file() or path.is_symlink() or any(p in EXCLUDED or p.endswith('.egg-info') for p in rel.parts):
                continue
            if rel.parts[0] not in FOLDERS and str(rel) not in ROOT_FILES:
                continue
            if path.name.startswith((".env", "~$")) or path.suffix in {".pyc", ".db", ".key", ".pem"}:
                continue
            archive.write(path, "travel-reimbursement-assistant/" + rel.as_posix())
    print(dest)


if __name__ == "__main__":
    build()
