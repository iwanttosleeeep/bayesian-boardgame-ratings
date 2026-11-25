# P6 shared plotting theme — keeps every P6 figure in one visual language.
# Sourced by 01_bgg_benchmark.R and 02_rank_uncertainty.R.

suppressPackageStartupMessages({
  library(ggplot2)
})

P6_INK    <- "#1a1a19"   # primary text
P6_INK2   <- "#52514e"   # secondary text
P6_MUTED  <- "#8a8984"   # annotations, reference lines
P6_GRID   <- "#e5e4e0"
P6_SURF   <- "#fcfcfb"
P6_BLUE   <- "#2a78d6"   # our model
P6_ORANGE <- "#eb6834"   # BGG benchmark
P6_AQUA   <- "#1baf7a"

theme_p6 <- function(base_size = 11) {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(
      plot.background   = element_rect(fill = P6_SURF, colour = NA),
      panel.background  = element_rect(fill = P6_SURF, colour = NA),
      panel.grid.major  = element_line(colour = P6_GRID, linewidth = 0.35),
      panel.grid.minor  = element_blank(),
      axis.text         = element_text(colour = P6_INK2),
      axis.title        = element_text(colour = P6_INK2),
      plot.title        = element_text(colour = P6_INK, face = "bold", hjust = 0),
      plot.subtitle     = element_text(colour = P6_INK2, hjust = 0),
      plot.caption      = element_text(colour = P6_MUTED, hjust = 0, size = 8),
      # anchor titles to the whole canvas so long text cannot overflow the device
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      plot.margin       = margin(10, 18, 8, 12),
      legend.position   = "top",
      legend.justification = "left",
      legend.title      = element_text(colour = P6_INK2),
      strip.text        = element_text(colour = P6_INK, face = "bold", hjust = 0)
    )
}

save_p6 <- function(p, file, width = 8, height = 5, dpi = 200) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  ggsave(file, p, width = width, height = height, dpi = dpi, bg = P6_SURF)
  invisible(file)
}
