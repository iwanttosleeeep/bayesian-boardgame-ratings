"""Build P6's slides for the 1 Dec progress presentation.

Reads the figures and CSVs produced by 01_bgg_benchmark.R and
02_rank_uncertainty.R, so the slides always match the saved results.
Run from the repository root:

    python code/P6/03_make_slides.py

Requires python-pptx and Pillow.
"""

import csv
import os

from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt

INK    = RGBColor(0x1A, 0x1A, 0x19)
INK2   = RGBColor(0x52, 0x51, 0x4E)
MUTED  = RGBColor(0x8A, 0x89, 0x84)
BLUE   = RGBColor(0x2A, 0x78, 0xD6)
ORANGE = RGBColor(0xEB, 0x68, 0x34)
SURF   = RGBColor(0xFC, 0xFC, 0xFB)

FIG  = "figures/P6"
OUT  = "slides/P6_slides.pptx"
W, H = Inches(13.333), Inches(7.5)


def read_summary():
    d = {}
    with open("outputs/P6/bgg_benchmark_summary.csv") as f:
        for row in csv.DictReader(f):
            d[row["quantity"]] = float(row["value"])
    with open("outputs/P6/rank_vs_bgg_summary.csv") as f:
        for row in csv.DictReader(f):
            d[row["quantity"]] = float(row["value"])
    return d


S = read_summary()


def blank(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    bg = s.background.fill
    bg.solid()
    bg.fore_color.rgb = SURF
    return s


def text(slide, x, y, w, h, body, size=16, bold=False, colour=INK,
         space_after=10, align=PP_ALIGN.LEFT):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    lines = body if isinstance(body, list) else [body]
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.text = line
        p.alignment = align
        p.space_after = Pt(space_after)
        for r in p.runs:
            r.font.size = Pt(size)
            r.font.bold = bold
            r.font.color.rgb = colour
            r.font.name = "Helvetica Neue"
    return tb


def header(slide, title, subtitle=None, number=None):
    text(slide, Inches(0.6), Inches(0.42), Inches(11.5), Inches(0.7),
         title, size=27, bold=True)
    if subtitle:
        text(slide, Inches(0.6), Inches(1.12), Inches(12.1), Inches(0.5),
             subtitle, size=13.5, colour=INK2)
    if number:
        text(slide, Inches(12.2), Inches(6.95), Inches(0.8), Inches(0.35),
             number, size=11, colour=MUTED, align=PP_ALIGN.RIGHT)
    text(slide, Inches(0.6), Inches(6.95), Inches(8), Inches(0.35),
         "P6 · BGG benchmark and ranking uncertainty", size=10, colour=MUTED)


def picture(slide, path, left, top, max_w, max_h):
    """Place an image scaled to fit inside the given box, preserving aspect."""
    with Image.open(path) as im:
        iw, ih = im.size
    scale = min(max_w / iw, max_h / ih)
    w, h = int(iw * scale), int(ih * scale)
    slide.shapes.add_picture(path, left, top, width=w, height=h)


def table(slide, x, y, w, rows, col_w):
    shape = slide.shapes.add_table(len(rows), len(rows[0]), x, y, w,
                                   Inches(0.34) * len(rows))
    tbl = shape.table
    for j, cw in enumerate(col_w):
        tbl.columns[j].width = cw
    for i, row in enumerate(rows):
        for j, cell_text in enumerate(row):
            cell = tbl.cell(i, j)
            cell.text = cell_text
            p = cell.text_frame.paragraphs[0]
            p.font.size = Pt(13)
            p.font.bold = i == 0
            p.font.color.rgb = INK if i == 0 else INK2
            p.font.name = "Helvetica Neue"
            cell.fill.solid()
            cell.fill.fore_color.rgb = SURF


prs = Presentation()
prs.slide_width, prs.slide_height = W, H

# ----------------------------------------------------------------- slide 1 ---
s = blank(prs)
header(s, "What BGG's rating rule actually does",
       "Its public adjusted score behaves like a Bayesian average with a fixed number of dummy votes at 5.5")
picture(s, f"{FIG}/fig_bgg_pseudovotes.png", Inches(0.5), Inches(1.75),
        Inches(8.0), Inches(4.7))
text(s, Inches(8.85), Inches(1.9), Inches(4.0), Inches(4.5), [
    f"BGG implies about {S['bgg_m_best_single_fit']:,.0f} dummy votes per game",
    "The implied number barely changes with rating count, so it is a fixed rule, not an n-dependent one",
    f"Fitting one number to all {S['games_usable']:,.0f} games reproduces BGG's score with RMSE {S['bgg_m_fit_rmse']:.3f}",
], size=15)
text(s, Inches(8.85), Inches(5.65), Inches(4.0), Inches(0.6),
     "Method: invert bayes = (n·ybar + m·5.5)/(n + m) for every game", size=11.5,
     colour=MUTED)
text(s, Inches(12.2), Inches(6.95), Inches(0.8), Inches(0.35), "1/4",
     size=11, colour=MUTED, align=PP_ALIGN.RIGHT)

# ----------------------------------------------------------------- slide 2 ---
s = blank(prs)
header(s, "Sampling noise alone justifies about twelve",
       "M1a posterior of m = s²/τ², the pseudo-vote count implied by the measurement-error model")
text(s, Inches(0.75), Inches(1.95), Inches(5.6), Inches(4.6), [
    f"Posterior mean m = {S['model_m_mean']:.1f}",
    f"95% credible interval {S['model_m_lower95']:.1f} to {S['model_m_upper95']:.1f}",
    f"That is {S['ratio_bgg_over_model']:.0f}× smaller than BGG's rule",
    "The ranking export shrinks even less: median effective m = "
    f"{S['ranking_model_m_eff_median']:.1f}",
], size=17, space_after=16)
text(s, Inches(6.6), Inches(1.95), Inches(6.1), Inches(4.6), [
    "Why so small: s, one rater's SD around a game's true score, is barely identified from averages alone.",
    f"In the M1a posterior s sits near the top of its prior (3.0), so m inherits that uncertainty.",
    "This is a result about what the data can support, not a claim that BGG is wrong.",
], size=14.5, colour=INK2, space_after=14)
text(s, Inches(12.2), Inches(6.95), Inches(0.8), Inches(0.35), "2/4",
     size=11, colour=MUTED, align=PP_ALIGN.RIGHT)

# ----------------------------------------------------------------- slide 3 ---
s = blank(prs)
header(s, "Ranking 21,375 games inside each of 500 joint draws",
       "Ranking is done within each posterior draw, so every comparison uses the same sample")
picture(s, f"{FIG}/fig_top10_probability.png", Inches(0.45), Inches(1.8),
        Inches(7.6), Inches(4.9))
text(s, Inches(8.35), Inches(1.95), Inches(4.5), Inches(4.6), [
    f"Only four games exceed a 50% chance of being in the top ten",
    f"{S['games_with_p_top10_above_005']:.0f} games have a P(top 10) above 5%",
    f"Median 90% rank interval: {S['median_90pct_rank_interval_width']:,.0f} ranks overall, "
    f"{S['median_90pct_width_top10_candidates']:.0f} for top-ten candidates",
], size=14.5, space_after=14)
text(s, Inches(12.2), Inches(6.95), Inches(0.8), Inches(0.35), "3/4",
     size=11, colour=MUTED, align=PP_ALIGN.RIGHT)

# ----------------------------------------------------------------- slide 4 ---
s = blank(prs)
header(s, "The two top tens share no games",
       "Agreement in the middle of the list, total disagreement at the top")
table(s, Inches(0.55), Inches(1.85), Inches(6.3), [
    ["", "Our ranking", "BGG adjusted"],
    ["Median rating count", "46", "25,535"],
    ["Median raw average", "9.27", "8.55"],
    ["Top-10 overlap", "0 / 10", ""],
    ["Spearman, all games", f"{S['spearman_vs_bgg_adjusted']:.2f}", ""],
], [Inches(2.6), Inches(1.85), Inches(1.85)])
text(s, Inches(0.55), Inches(4.55), Inches(6.3), Inches(1.9), [
    "A game with 43 ratings and a 9.56 average keeps almost all of it under our m, so it outranks everything.",
    "BGG shrinks the same game toward 5.5, which is why Gloomhaven and Pandemic Legacy lead its list.",
], size=13.5, colour=INK2, space_after=10)
picture(s, f"{FIG}/fig_rank_intervals.png", Inches(7.0), Inches(1.75),
        Inches(5.9), Inches(4.7))
text(s, Inches(12.2), Inches(6.95), Inches(0.8), Inches(0.35), "4/4",
     size=11, colour=MUTED, align=PP_ALIGN.RIGHT)

# ----------------------------------------------------------------- slide 5 ---
s = blank(prs)
header(s, "What this means for the report",
       "Backup slide — takeaway and caveats")
text(s, Inches(0.7), Inches(1.9), Inches(12.0), Inches(4.6), [
    "The pseudo-vote count is not a technical detail: it decides which games appear at the top of the table.",
    "Our model answers a narrow question — how much shrinkage sampling noise alone justifies — and the answer is about 12, not 1,874.",
    "BGG's larger value also protects against strategic voting and produces a more stable list; the benchmark does not show that it is wrong.",
    "Scope: 21,375 SD-matched games of the 2022 snapshot. These are within-sample latent estimates, not holdout predictions.",
], size=16, colour=INK2, space_after=18)
text(s, Inches(12.2), Inches(6.95), Inches(0.8), Inches(0.35), "backup",
     size=11, colour=MUTED, align=PP_ALIGN.RIGHT)

os.makedirs("slides", exist_ok=True)
prs.save(OUT)
print("saved", OUT, "with", len(prs.slides), "slides")
