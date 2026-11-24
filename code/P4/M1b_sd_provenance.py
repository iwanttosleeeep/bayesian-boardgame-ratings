"""Standard-library source provenance. No fitting or destructive operations.
Run `python code/P4/M1b_sd_provenance.py capture` BEFORE a fresh run,
or `... verify` to check the original execution's working-tree bytes.
"""
from pathlib import Path
import csv
import hashlib
import subprocess
import sys

root = Path("outputs/P4/ExternalSD_6416")
manifest = root / "source_manifest.csv"
mode = sys.argv[1] if len(sys.argv) > 1 else "verify"
if mode == "capture":
    if list(root.rglob("inputs.rds")) or (root / "matched_inputs.rds").exists():
        raise SystemExit("Existing execution protected; use a fresh run directory")
    root.mkdir(parents=True, exist_ok=True)
    paths = [Path("dev_subsample.csv"),
             Path("outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv"),
             *sorted(Path("code/P4").glob("M1b_sd_*.R")),
             Path("code/P4/run_sd.ps1"), Path("code/P4/M1b_prepare.R"),
             Path("code/P4/M1b_baseline.bug")]
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    with manifest.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["path", "bytes", "sha256", "base_commit"])
        for p in paths:
            writer.writerow([p.as_posix(), p.stat().st_size,
                             hashlib.sha256(p.read_bytes()).hexdigest(), commit])
elif mode == "verify":
    with manifest.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            p = Path(row["path"])
            assert p.stat().st_size == int(row["bytes"]), p
            assert hashlib.sha256(p.read_bytes()).hexdigest() == row["sha256"], p
elif mode == "package":
    # Records postprocessing/dependencies separately; never changes fit-time hashes.
    paths = [*sorted(Path("code/P4").glob("M1b_sd_*")),
             Path("code/P4/M1b_diagnostics.R"), Path("code/P4/P4_runtime.ps1")]
    with (root / "postprocessing_sources.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["path", "bytes", "sha256", "note"])
        for p in paths:
            writer.writerow([p.as_posix(), p.stat().st_size,
                             hashlib.sha256(p.read_bytes()).hexdigest(),
                             "post-fit working-tree bytes; fit-time manifest remains separate"])
    with (root / "file_manifest.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["path", "bytes", "sha256", "git_policy"])
        for p in sorted(root.rglob("*.rds")):
            shared = p.name == "pointwise_loglik_share.rds" and p.parent.name in (
                "matched_baseline", "external_sd")
            writer.writerow([p.relative_to(root).as_posix(), p.stat().st_size,
                             hashlib.sha256(p.read_bytes()).hexdigest(),
                             "uploaded" if shared else "local_only_ignored_regenerate_with_run_sd"])
else:
    raise SystemExit("Specify capture, verify or package")
print("PASS: source provenance", mode)
