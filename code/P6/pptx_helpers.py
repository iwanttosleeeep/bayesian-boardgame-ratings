"""Shared layout helpers for the P6 and group slide decks.

Kept in one place so every slide in the deck uses the same colours, margins
and type sizes. Imported by 03_make_slides.py and 04_make_group_deck.py.
"""

from PIL import Image
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt

INK    = RGBColor(0x1A, 0x1A, 0x19)
INK2   = RGBColor(0x52, 0x51, 0x4E)
MUTED  = RGBColor(0x8A, 0x89, 0x84)
BLUE   = RGBColor(0x2A, 0x78, 0xD6)
ORANGE = RGBColor(0xEB, 0x68, 0x34)
SURF   = RGBColor(0xFC, 0xFC, 0xFB)
RULE   = RGBColor(0xE5, 0xE4, 0xE0)

W, H = Inches(13.333), Inches(7.5)
FONT = "Helvetica Neue"


def blank(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    bg = s.background.fill
    bg.solid()
    bg.fore_color.rgb = SURF
    return s


def text(slide, x, y, w, h, body, size=16, bold=False, colour=INK,
         space_after=10, align=PP_ALIGN.LEFT, line_spacing=1.0):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    lines = body if isinstance(body, list) else [body]
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.text = line
        p.alignment = align
        p.space_after = Pt(space_after)
        p.line_spacing = line_spacing
        for r in p.runs:
            r.font.size = Pt(size)
            r.font.bold = bold
            r.font.color.rgb = colour
            r.font.name = FONT
    return tb


def header(slide, title, subtitle=None, footer=None, number=None):
    text(slide, Inches(0.6), Inches(0.42), Inches(12.1), Inches(0.7),
         title, size=26, bold=True)
    if subtitle:
        text(slide, Inches(0.6), Inches(1.10), Inches(12.1), Inches(0.5),
             subtitle, size=13.5, colour=INK2)
    if footer:
        text(slide, Inches(0.6), Inches(6.95), Inches(9), Inches(0.35),
             footer, size=10, colour=MUTED)
    if number:
        text(slide, Inches(12.2), Inches(6.95), Inches(0.8), Inches(0.35),
             number, size=11, colour=MUTED, align=PP_ALIGN.RIGHT)


def picture(slide, path, left, top, max_w, max_h):
    """Place an image scaled to fit inside the box, preserving aspect ratio."""
    with Image.open(path) as im:
        iw, ih = im.size
    scale = min(max_w / iw, max_h / ih)
    w, h = int(iw * scale), int(ih * scale)
    return slide.shapes.add_picture(path, left, top, width=w, height=h)


def table(slide, x, y, rows, col_w, font_size=13, row_h=Inches(0.34)):
    width = sum(col_w, Inches(0))
    shape = slide.shapes.add_table(len(rows), len(rows[0]), x, y, width,
                                   row_h * len(rows))
    tbl = shape.table
    for j, cw in enumerate(col_w):
        tbl.columns[j].width = cw
    for i, row in enumerate(rows):
        for j, cell_text in enumerate(row):
            cell = tbl.cell(i, j)
            cell.text = cell_text
            p = cell.text_frame.paragraphs[0]
            p.font.size = Pt(font_size)
            p.font.bold = i == 0
            p.font.color.rgb = INK if i == 0 else INK2
            p.font.name = FONT
            cell.fill.solid()
            cell.fill.fore_color.rgb = SURF
    return shape


def note(slide, body):
    """Speaker note, so caveats travel with the file without cluttering the slide."""
    slide.notes_slide.notes_text_frame.text = body
