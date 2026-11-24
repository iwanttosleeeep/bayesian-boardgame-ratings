"""Hash frozen inputs/sources and exported artifacts; no fitting or credentials."""
from pathlib import Path
import csv, hashlib, json, subprocess, sys

root=Path("outputs/P4/Holdout_3209")
mode=sys.argv[1] if len(sys.argv)>1 else "verify"
def digest(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for block in iter(lambda:f.read(1048576),b""): h.update(block)
    return h.hexdigest()
manifest=root/"source_manifest.csv"
if mode=="capture":
    if manifest.exists() or (root/"prediction_inputs.rds").exists():
        raise SystemExit("Existing execution protected; use a fresh output directory")
    root.mkdir(parents=True,exist_ok=True)
    paths=[Path("comparison_sample.csv"), Path("code/P4/M1b_prepare.R"),
           Path("code/P4/M1b_baseline.bug"),Path("code/P4/P4_runtime.ps1"),
           *sorted(Path("code/P4").glob("*holdout*")),
           Path("code/P5/04_Extended_holdout_validation.R"),
           Path("code/P5/07_Baseline_vs_Extended_comparison.R"),
           Path("code/P5/11_Export_Full_Cleaned_Data_Theta_for_P6.R"),
           Path("outputs/P5/P6_Full_Handoff/P6_all_21631_SD_matching_audit.csv"),
           Path("outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv"),
           Path("outputs/P5/M1a_Extended_ExternalSD/holdout/holdout_grouped_PPC.csv"),
           Path("outputs/P5/M1a_Extended_ExternalSD/holdout/holdout_summary.csv")]
    for label in ("matched_baseline","external_sd"):
        folder=Path("outputs/P4/ExternalSD_6416")/label
        paths.extend(folder/name for name in ("inputs.rds","preprocessing.rds","model.bug",
                     "run_settings.rds","diagnostics.csv","source_manifest.csv","train_game_ids.csv",
                     "chain_1.rds","chain_2.rds","chain_3.rds","chain_4.rds"))
    base=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()
    with manifest.open("w",newline="",encoding="utf-8") as f:
        w=csv.writer(f);w.writerow(["path","bytes","sha256","base_commit"])
        for p in sorted(set(paths)):
            w.writerow([p.as_posix(),p.stat().st_size,digest(p),base])
elif mode=="verify":
    with manifest.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            p=Path(row["path"])
            assert p.stat().st_size==int(row["bytes"]) and digest(p)==row["sha256"],p
elif mode=="package":
    # CSV/text hashes are canonical Git LF bytes; binary hashes are unchanged.
    with (root/"file_manifest.csv").open("w",newline="",encoding="utf-8") as f:
        w=csv.writer(f);w.writerow(["path","bytes","sha256","storage","hash_bytes"])
        for p in sorted(root.rglob("*")):
            if not p.is_file() or p.name=="file_manifest.csv":continue
            local=p.suffix==".rds" or p.name in ("run.log","run_errors.log","sessionInfo.txt")
            data=p.read_bytes()
            convention="exact binary bytes"
            if p.suffix in (".csv",".txt",".md") or p.suffix==".log":
                data=data.replace(b"\r\n",b"\n");convention="LF normalized (Git text)"
            w.writerow([p.relative_to(root).as_posix(),len(data),hashlib.sha256(data).hexdigest(),
                        "local_only_ignored" if local else "uploaded",convention])
else: raise SystemExit("Specify capture, verify or package")
print("PASS: holdout provenance",mode)
