## Hex logo template for realestatebr
## Edit the STYLE section below, then source() this file.
## Output: man/figures/hexlogo.png

library(ggplot2)
library(dplyr)
library(purrr)

# Irregular grid — unequal spacing is key for Kandinsky feel
xs <- c(0, 0.15, 0.45, 0.7, 1.0, 1.25) # 4 columns, irregular widths
ys <- c(0, 0.4, 0.9, 1.2, 2.0, 2.1) # 4 rows, irregular heights

# Build all 16 cells
cells <- map2_dfr(
  rep(1:(length(xs) - 1), each = length(ys) - 1),
  rep(1:(length(ys) - 1), times = length(xs) - 1),
  function(ci, ri) {
    tibble(
      cell = (ci - 1) * (length(ys) - 1) + ri,
      col = ci,
      row = ri,
      x = c(xs[ci], xs[ci + 1], xs[ci + 1], xs[ci]),
      y = c(ys[ri], ys[ri], ys[ri + 1], ys[ri + 1])
    )
  }
)

# Kandinsky palette — assign per cell, leave some NA (empty)
kandinsky_colors <- c(
  "#1a1a2e",
  "#c0392b",
  "#e8c547",
  "#2980b9",
  "#8e44ad",
  "#e67e22",
  "#27ae60"
)

cell_groups <- tibble(cell = 1:25) |>
  mutate(
    fill_color = case_when(
      cell == 1 ~ kandinsky_colors[1],
      cell == 2 ~ kandinsky_colors[3],
      cell == 3 ~ NA_character_, # empty
      cell == 4 ~ kandinsky_colors[5],
      cell == 5 ~ kandinsky_colors[2],
      cell == 6 ~ NA_character_,
      cell == 7 ~ kandinsky_colors[4],
      cell == 8 ~ kandinsky_colors[3],
      cell == 9 ~ NA_character_,
      cell == 10 ~ kandinsky_colors[6],
      cell == 11 ~ kandinsky_colors[1],
      cell == 12 ~ NA_character_,
      cell == 13 ~ kandinsky_colors[4],
      cell == 14 ~ kandinsky_colors[2],
      cell == 15 ~ kandinsky_colors[7],
      cell == 16 ~ kandinsky_colors[3],
      cell == 17 ~ kandinsky_colors[4],
      cell == 18 ~ kandinsky_colors[2],
      cell == 19 ~ kandinsky_colors[7],
      cell == 20 ~ kandinsky_colors[3],
      cell == 21 ~ NA_character_,
      cell == 22 ~ kandinsky_colors[6],
      cell == 23 ~ kandinsky_colors[1],
      cell == 24 ~ NA_character_,
      cell == 25 ~ kandinsky_colors[4]
    )
  )

cells <- cells |> left_join(cell_groups, by = "cell")

# Your transformations
k <- -0.2
tx <- 0.5
ty <- 0.25
theta <- -pi / 12

cells_transformed <- cells |>
  mutate(
    x = x + k * y - tx,
    y = y + ty,
    x_new = x * cos(theta) - y * sin(theta),
    y_new = y * cos(theta) + x * sin(theta),
  ) |>
  select(cell, col, row, fill_color, x = x_new, y = y_new)

inner <- ggplot(cells_transformed) +
  geom_polygon(
    data = ~ filter(.x, !is.na(fill_color)),
    aes(x = x, y = y, group = cell, fill = fill_color),
    color = "black",
    linewidth = 0.75
  ) +
  geom_polygon(
    data = ~ filter(.x, is.na(fill_color)),
    aes(x = x, y = y, group = cell),
    fill = NA,
    color = "black",
    linewidth = 0.8
  ) +
  geom_abline(
    slope = 0.5,
    intercept = -1.5,
    lwd = 0.5
  ) +
  annotate(
    "text",
    x = -0.5,
    y = 1.5,
    label = "realestatebr",
    family = "Futura",
    size = 12,
    color = "black",
    angle = 90 - 4
  ) +
  scale_x_continuous(limits = c(-1, 1)) +
  scale_fill_identity() +
  # coord_equal(xlim = c(-3, 3), ylim = c(-3, 5)) +
  coord_equal() +
  theme_void() +
  theme(plot.background = element_rect(fill = "#f5f0e8", color = NA))

ggsave(
  "man/figures/inner_temp.png",
  plot = inner,
  width = 5,
  height = 6,
  dpi = 600,
  bg = "transparent"
)


# ── STYLE ────────────────────────────────────────────────────────────────────

library(hexSticker)
# Palette
col_bg <- "#f5f0e8" # hex background
col_border <- "#000000" # hex border
col_text <- "#000000" # package name

# Pass the path instead of the object
sticker(
  subplot = "man/figures/inner_temp.png",
  s_x = 0.9,
  s_y = 0.8,
  s_width = 1,
  s_height = 1,
  package = "",
  h_fill = col_bg,
  h_color = "black",
  h_size = 1.2,
  filename = "man/figures/hexlogo.png",
  dpi = 600,
  white_around_sticker = TRUE
)


# Post-process dark version to add transparency
# The magick package removes white background by making it transparent
library(magick)

# Read the dark version
p <- image_read("man/figures/hexlogo.png")

# Apply transparency to white areas at each corner
# The fuzz parameter allows for slight color variations
# Each point targets a corner of the image
pp <- p %>%
  image_fill(
    color = "transparent",
    refcolor = "white",
    fuzz = 4,
    point = "+1+1"
  ) %>%
  image_fill(
    color = "transparent",
    refcolor = "white",
    fuzz = 4,
    point = "+517+1"
  ) %>%
  image_fill(
    color = "transparent",
    refcolor = "white",
    fuzz = 4,
    point = "+1+599"
  ) %>%
  image_fill(
    color = "transparent",
    refcolor = "white",
    fuzz = 4,
    point = "+517+599"
  )

# Save the final version as logo_cropped.png
# This is the official package logo
image_write(image = pp, path = "man/figures/logo_cropped.png")
