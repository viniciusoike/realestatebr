library(ggplot2)
library(realestatebr)
library(dplyr, warn.conflicts = FALSE)

# Get FipeZap index
fipezap <- get_dataset("rppi", table = "fipezap", source = "fresh")

# Brazil national index
rppi_spo <- fipezap |>
  filter(
    name_muni == "São Paulo",
    market == "residential",
    rooms == "total",
    variable == "acum12m",
    date >= as.Date("2019-01-01")
  )

p1 <- ggplot(rppi_spo, aes(x = date, y = value, color = rent_sale)) +
  geom_line(lwd = 0.8) +
  geom_hline(yintercept = 0) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = seq(-0.05, 0.15, by = 0.05) * 100, ) +
  labs(
    title = "Brazil Property Price Index",
    x = NULL,
    y = "YoY chg. (%)",
    color = ""
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    palette.colour.discrete = c("#2C6BB3", "#1abc9c", "#f39c12")
  )

# Get BIS international data
bis <- get_dataset("rppi_bis", source = "fresh")

# Compare countries
bis_compare <- bis |>
  filter(
    reference_area %in% c("Brazil", "United States", "Japan"),
    is_nominal == FALSE,
    unit == "Index, 2010 = 100",
    date >= as.Date("2010-01-01")
  )

p2 <- ggplot(bis_compare, aes(x = date, y = value, color = reference_area)) +
  geom_line(lwd = 0.8) +
  geom_hline(yintercept = 100) +
  labs(
    title = "Real Property Prices - International",
    x = NULL,
    y = "Index (2010 = 100)",
    color = ""
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    palette.colour.discrete = c("#2C6BB3", "#1abc9c", "#f39c12")
  )

ggsave(
  "man/figures/README-rppi-example-1.png",
  p1,
  width = 6.5,
  height = 6.5 / 1.618
)

ggsave(
  "man/figures/README-bis-example-1.png",
  p2,
  width = 6.5,
  height = 6.5 / 1.618
)
