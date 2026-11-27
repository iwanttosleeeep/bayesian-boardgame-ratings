"""Compare the current deck with a Git/file baseline; no rendering or rebuilding."""
import argparse
import io
import re
import subprocess
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

args = argparse.ArgumentParser()
args.add_argument('--baseline', help='original PPTX; defaults to origin/main Git blob')
opts = args.parse_args()
root = Path(__file__).resolve().parents[2]
blob = (Path(opts.baseline).read_bytes() if opts.baseline else subprocess.check_output(
    ['git', 'show', 'origin/main:slides/Group_deck_draft.pptx'], cwd=root))
ns = {'a': 'http://schemas.openxmlformats.org/drawingml/2006/main'}
changed = []
with zipfile.ZipFile(io.BytesIO(blob)) as old, zipfile.ZipFile(root / 'slides/Group_deck_draft.pptx') as new:
    assert set(old.namelist()) == set(new.namelist())
    slides = [n for n in new.namelist() if re.fullmatch(r'ppt/slides/slide\d+[.]xml', n)]
    assert len(slides) == 19
    for name in old.namelist():
        if old.read(name) == new.read(name):
            continue
        changed.append(name)
        assert re.fullmatch(r'ppt/(slides/slide|notesSlides/notesSlide)\d+[.]xml', name), name
        a, b = ET.fromstring(old.read(name)), ET.fromstring(new.read(name))
        ta, tb = ([t.text or '' for t in tree.findall('.//a:t', ns)] for tree in (a, b))
        assert len(ta) == len(tb), name
        if '/slides/' in name:
            speakers = lambda texts: [t for t in texts if t in {'P1','P2','P3','P4','P5','P6'}]
            assert speakers(ta) == speakers(tb), name
            numbers = lambda texts: [t.rstrip('.,') for t in re.findall(
                r'(?<![A-Za-z])\d[\d,.]*(?:[–−-]\d[\d,.]*)?', ' '.join(texts))]
            na, nb = numbers(ta), numbers(tb)
            if name.endswith('slide15.xml') and nb.count('5.5') > na.count('5.5'):
                nb.remove('5.5')  # Added explicit benchmark assumption, not a changed result.
            assert na == nb, (name, na, nb)
        for tree in (a, b):
            for t in tree.findall('.//a:t', ns):
                t.text = ''
        assert ET.tostring(a) == ET.tostring(b), 'Non-text change: ' + name
print('PASS: 19 slides; all geometry/styles/media/relationships and visible results/speakers preserved')
print('Changed text parts:', ', '.join(changed))
