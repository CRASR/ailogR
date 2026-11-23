# Draws the ailogR hex sticker options into man/figures/. Run from the package root.
# Size follows the hexb.in sticker standard (pointy top, 2 in tall).
library(ggplot2)

green <- "#154734"  # Baylor green
gold <- "#FFB81C"   # Baylor gold
cream <- "#FFF3D6"

hexagon <- data.frame(angle = seq(30, 330, by = 60) * pi / 180) |>
  # 0.96 leaves room for the border inside the image.
  transform(x = 0.96 * cos(angle), y = 0.96 * sin(angle))

hex_fill <- geom_polygon(aes(x, y), hexagon, fill = green)
hex_border <- geom_polygon(aes(x, y), hexagon, fill = NA, colour = gold, linewidth = 2.2,
                           linejoin = "round")
title <- annotate("text", x = 0, y = -0.5, label = "ailogR", colour = cream,
                  size = 7.5, fontface = "bold", family = "DejaVu Sans")


entries <- data.frame(y = c(0.4, 0.18, -0.04), chip = c(cream, gold, "#B07A00"),
                      text_end = c(0.36, 0.22, 0.12), linetype = c("solid", "solid", "dashed"))

# Four-pointed sparkles: astroid-like curves, plumped with a power below 3.
sparkles <- expand.grid(t = seq(0, 2 * pi, length.out = 100),
                        id = 1:2) |>
  transform(x0 = c(0.33, 0.45)[id], y0 = c(-0.04, 0.05)[id], size = c(0.1, 0.05)[id]) |>
  transform(x = x0 + size * sign(cos(t)) * abs(cos(t))^2.5,
            y = y0 + size * sign(sin(t)) * abs(sin(t))^2.5)

ledger <- ggplot(entries) +
  hex_fill +
  geom_rect(aes(xmin = -0.52, xmax = 0.52, ymin = y - 0.08, ymax = y + 0.08, linetype = linetype),
            fill = "#0E3326", colour = gold, linewidth = 0.6) +
  geom_rect(aes(xmin = -0.45, xmax = -0.31, ymin = y - 0.05, ymax = y + 0.05), fill = entries$chip) +
  geom_segment(aes(x = -0.21, xend = text_end, y = y, yend = y), colour = cream,
               linewidth = 2.2, lineend = "round", alpha = 0.85) +
  geom_polygon(aes(x, y, group = id), sparkles, fill = gold) +
  scale_linetype_identity() +
  title +
  hex_border


  p <- ledger +
    coord_fixed(xlim = c(-0.87, 0.87), ylim = c(-1, 1), expand = FALSE) +
    theme_void()

  ggsave("man/figures/logo.png", p,
         width = 1.73, height = 2, dpi = 300, bg = "transparent", device = ragg::agg_png)
