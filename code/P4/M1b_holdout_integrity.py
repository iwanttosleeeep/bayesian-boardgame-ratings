"""Before/after file protection and independent exported-density checks."""
from pathlib import Path
import csv, hashlib, json, math, sys

root=Path("outputs/P4/Holdout_3209")
inventory=Path(".local/holdout_protected_hashes.json")
def sha(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for block in iter(lambda:f.read(1048576),b""):h.update(block)
    return h.hexdigest()
mode=sys.argv[1] if len(sys.argv)>1 else "verify"
if mode=="snapshot":
    if inventory.exists():raise SystemExit("Existing protection inventory preserved; use a fresh disposable checkout")
    inventory.parent.mkdir(exist_ok=True)
    paths=[p for folder in (Path("code/P4"),Path("outputs/P4")) for p in folder.rglob("*")
           if p.is_file() and root not in p.parents]
    inventory.write_text(json.dumps({p.as_posix():sha(p) for p in paths}),encoding="utf-8")
    print("PASS: protection inventory captured",len(paths))
elif mode=="verify":
    data=json.loads(inventory.read_text(encoding="utf-8"))
    for name,expected in data.items():assert sha(Path(name))==expected,name
    (root/"protection_validation.txt").write_text(
        f"PASS: all {len(data)} pre-existing P4 files unchanged by SHA256.\n"
        "Includes original posteriors, preprocessing, models, training results and WAIC handoffs; no fitting or tuning.\n",encoding="utf-8")
    read=lambda p:list(csv.DictReader(p.open(encoding="utf-8")))
    messages=[]
    for model in ("matched_baseline","external_sd"):
        rows=read(root/model/"chain_log_predictive_density.csv")
        pred=read(root/model/"holdout_game_predictions.csv")
        assert len(rows)==3209 and [r["id"] for r in rows]==[r["id"] for r in pred]
        error=0
        for r,t in zip(rows,pred):
            for field in ("n","observed_average","sd_hist","predictive_mean","predictive_lower",
                          "predictive_upper","predictive_sd","interval_width","log_predictive_density"):
                assert math.isfinite(float(t[field])),(model,t["id"],field)
            values=[float(r["X"+str(k)]) for k in range(1,5)]
            peak=max(values)
            direct=peak+math.log(sum(math.exp(v-peak) for v in values)/4)
            error=max(error,abs(direct-float(t["log_predictive_density"])))
        assert error<1e-10
        messages.append(f"PASS: {model}: all 3209 densities independently recombined from four equal chain mixtures; max error {error:.6g}; prediction columns finite")
    (root/"all_game_density_validation.txt").write_text("\n".join(messages)+"\n",encoding="utf-8")
    p=Path(__file__)
    with (root/"postprocessing_sources.csv").open("w",newline="",encoding="utf-8") as f:
        w=csv.writer(f);w.writerow(["path","sha256","note"])
        w.writerow([p.resolve().relative_to(Path.cwd().resolve()).as_posix(),sha(p),"delivery integrity helper added after predictive execution; fit-time source manifest unchanged"])
    print("PASS: protected originals",len(data))
    print("\n".join(messages))
else:raise SystemExit("Specify snapshot or verify")
