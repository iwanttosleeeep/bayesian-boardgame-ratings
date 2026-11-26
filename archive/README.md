# Archived material

Retained evidence and superseded presentation material as of 26 November 2026.
Paths in the first column are the former repository locations; links point to
the retained files. Run archived scripts from the repository root.

| Former location → archived item | Current replacement | Why it is kept |
| --- | --- | --- |
| `slides/P6_slides.pptx` → [standalone P6 deck](slides/P6_slides.pptx) | [Group deck](../slides/Group_deck_draft.pptx) | Preserves P6's earlier presentation without competing with the agreed group running order. |
| `code/P6/03_make_slides.py` → [standalone deck builder](code/P6/03_make_slides.py) | [Group deck builder](../code/P6/04_make_group_deck.py) | Reproduces the retired deck using the shared layout helpers; its output path now stays in the archive. |
| `outputs/P5/WAIC_Comparison_6489/` → [6,489-game WAIC comparison](outputs/P5/WAIC_Comparison_6489/README.md) | [6,416-game four-model WAIC](../outputs/P5/WAIC_Comparison_6416/README.md) and [3,209-game holdout ELPD](../outputs/P5/Holdout_Comparison_3209/README.md) | Retains the earlier M0/M1a/M1b comparison, sampler check and interpretation warnings; exploratory holdout ELPD is now primary. |
| `outputs/P5/M1a_WAIC_6489/` → [6,489-game M1a refit](outputs/P5/M1a_WAIC_6489/README.md) | [M1a Baseline](../outputs/P5/M1a_Baseline/) and [M1a Extended](../outputs/P5/M1a_Extended_ExternalSD/) for the current matched-SD comparison | Preserves the distinct refit, ordered IDs and likelihood/draw files needed by the earlier WAIC comparison and P1 grouped PPC; those consumers read the archive. |
| `outputs/P5/M1a_Model_Comparison/` → [two-model comparison](outputs/P5/M1a_Model_Comparison/) | [Four-model holdout comparison](../outputs/P5/Holdout_Comparison_3209/README.md), [four-model WAIC](../outputs/P5/WAIC_Comparison_6416/README.md) and [sensitivity analysis](../outputs/P5/Sensitivity_Analysis/) | Preserves the original per-game holdout, shrinkage and PPC summaries still used by the comparison and figure scripts. |

Archived results have not been refitted or recomputed. Older status statements
inside their READMEs remain historical records; the root [README](../README.md)
is the current status source.
