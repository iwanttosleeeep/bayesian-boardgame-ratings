from pathlib import Path
import subprocess,json,tempfile,os
root=Path(__file__).resolve().parents[2]; scripts=[root/p for p in ['code/P2/M0_run.R','code/P2/M0_cavi_run.R','code/P2/M0_cavi_selftest.R','code/P2/M0_make_share_loglik.R','code/P2/P2_M1b_timing.R','code/P4/M1b_export_WAIC_6489.R']]
scripts+=sorted((root/'code/P5').glob('*.R'))
results=[]
# Isolate tests from any real P5 cache in the user's launch directory.
with tempfile.TemporaryDirectory() as outside:
 env=os.environ.copy();env['P5_CACHE_DIR']=str(Path(outside)/'empty-P5-cache')
 for p in scripts:
  expected=2 if p.name.startswith(('04_Extended_holdout','11_Export')) else 0
  for cwd in (root,p.parent,Path(outside)):
   r=subprocess.run(['Rscript',str(p),'--check-paths'],cwd=cwd,capture_output=True,text=True,timeout=25,env=env)
   row={'script':str(p.relative_to(root)),'cwd':str(cwd),'exit':r.returncode,'expected':expected}
   if r.returncode!=expected: row['output']=r.stdout+r.stderr
   results.append(row)
  r=subprocess.run(['Rscript','-e','source('+json.dumps(str(p))+')','--check-paths'],cwd=outside,capture_output=True,text=True,timeout=25,env=env)
  row={'script':str(p.relative_to(root)),'cwd':'source() from unrelated directory','exit':r.returncode,'expected':expected}
  if r.returncode!=expected: row['output']=r.stdout+r.stderr
  results.append(row)
errors=[r for r in results if r['exit']!=r['expected']]
print(json.dumps({'runs':len(results),'errors':errors,'expected_missing_historical_cache':sum(r['exit']==2 for r in results)},indent=2))
assert not errors
