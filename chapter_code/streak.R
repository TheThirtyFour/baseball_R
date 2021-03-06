## ----setup, include=FALSE------------------------------------------------
source("global_config.R")

## ----warning=FALSE, message=FALSE----------------------------------------
library(tidyverse)
joe <- read_csv("../data/dimaggio.1941.csv")

## ------------------------------------------------------------------------
joe %>% summarize(AVG = sum(H) / sum(AB))

## ------------------------------------------------------------------------
joe %>% mutate(HIT = ifelse(H > 0, 1, 0)) -> joe

## ------------------------------------------------------------------------
pull(joe, HIT)

## ------------------------------------------------------------------------
streaks <- function(y) {
  x <- rle(y)
  class(x) <- "list"
  return(as_tibble(x))
}

## ------------------------------------------------------------------------
joe %>% 
  pull(HIT) %>% 
  streaks() %>%
  filter(values == 1) %>%
  pull(lengths)

## ------------------------------------------------------------------------
joe %>% 
  pull(HIT) %>% 
  streaks() %>%
  filter(values == 0) %>%
  pull(lengths)

## ------------------------------------------------------------------------
library(zoo)
moving_average <- function(df, width) {
  N <- nrow(df)
  df %>%
    transmute(Game = rollmean(1:N, k = width, fill = NA), 
              Average = rollsum(H, width, fill = NA) /
                        rollsum(AB, width, fill = NA))
}

## ----joe1, warning=FALSE, fig.cap="Moving average plot of DiMaggio's batting average for the 1941 season using a window of 10 games. The horizontal line shows DiMaggio's season batting average. The games where DiMaggio had at least one base hit are displayed on the horizontal axis."----
joe_ma <- moving_average(joe, 10)

ggplot(joe_ma, aes(Game, Average)) +
  geom_line() +
  geom_hline(data = summarize(joe, bavg = sum(H)/sum(AB)), 
             aes(yintercept = bavg)) +
  geom_rug(data = filter(joe, HIT == 1),
           aes(Rk, .3 * HIT), sides = "b")

## ----warning=FALSE-------------------------------------------------------
fields <- read_csv("../data/fields.csv")
data2016 <- read_csv("../data/all2016.csv", 
                     col_names = pull(fields, Header), 
                     na = character())

## ------------------------------------------------------------------------
ichiro_AB <- data2016 %>%
  filter(BAT_ID == "suzui001", AB_FL == TRUE)

## ------------------------------------------------------------------------
ichiro_AB %>% 
  mutate(H = ifelse(H_FL > 0, 1, 0),
         DATE = str_sub(GAME_ID, 4, 12),
         AB = 1) %>% 
  arrange(DATE) -> ichiro_AB

## ------------------------------------------------------------------------
ichiro_AB %>% 
  pull(H) %>% 
  streaks() %>%
  filter(values == 1) %>%
  pull(lengths)

## ------------------------------------------------------------------------
ichiro_AB %>%
  pull(H) %>%
  streaks() %>%
  filter(values == 0) -> ichiro_out
ichiro_out %>%
  pull(lengths) 

## ------------------------------------------------------------------------
ichiro_out %>%
  group_by(lengths) %>%
  count()

## ----ichiro1, warning=FALSE, fig.cap="Moving average plot of Ichiro Suzuki's batting average for the 2016 season using a window of 30 at-bats. The horizontal line shows Suzuki's season batting average. The at-bats where Suzuki had at least one base hit are shown on the horizontal axis."----
ichiro_AB %>% 
  mutate(AB_Num = row_number()) %>% 
  filter(H == 1) -> ichiro.H

moving_average(ichiro_AB, 30) %>% 
  ggplot(aes(Game, Average)) +
  geom_line() + xlab("AB") +
  geom_hline(yintercept = mean(ichiro_AB$H)) +
  geom_rug(data = ichiro.H,
           aes(AB_Num, .3 * H), sides = "b")

## ------------------------------------------------------------------------
longest_ofer <- function(batter) {
  data2016 %>% 
    filter(BAT_ID == batter, AB_FL == TRUE) %>% 
    mutate(H = ifelse(H_FL > 0, 1, 0),
           DATE = substr(GAME_ID, 4, 12)) %>% 
    arrange(DATE) %>% 
    pull(H) %>% 
    streaks() %>% 
    filter(values == 0) %>% 
    summarize(MAX_STREAK = max(lengths))
}

## ------------------------------------------------------------------------
longest_ofer("suzui001")

## ------------------------------------------------------------------------
data2016 %>% 
  group_by(BAT_ID) %>% 
  summarize(AB = sum(AB_FL)) %>% 
  filter(AB >= 400) %>% 
  pull(BAT_ID) -> players_400

reg_streaks <- players_400 %>%
  map_df(longest_ofer) %>%
  mutate(BAT_ID = players_400)

## ------------------------------------------------------------------------
library(Lahman)
reg_streaks %>%
  inner_join(Master, by = c("BAT_ID" = "retroID")) %>% 
  mutate(Name = paste(nameFirst, nameLast)) %>% 
  arrange(desc(MAX_STREAK)) %>%
  select(Name, MAX_STREAK) %>%
  head()

## ------------------------------------------------------------------------
ichiro_S <- ichiro_AB %>% 
  pull(H) %>%
  streaks() %>% 
  filter(values == 0) %>% 
  summarize(C = sum(lengths ^ 2)) %>% 
  pull()
ichiro_S

## ------------------------------------------------------------------------
random_mix <- function(y) {
  y %>% 
    sample() %>% 
    streaks() %>% 
    filter(values == 0) %>% 
    summarize(C = sum(lengths ^ 2)) %>% 
    pull()
}

## ------------------------------------------------------------------------
ichiro_random <- replicate(1000, random_mix(ichiro_AB$H))

## ----clump1, fig.cap="Histogram of one thousand values of the clumpiness statistic assuming all arrangements of hits and outs for Suzuki are equally likely. The observed value of the clumpiness statistic for Suzuki is shown using a vertical line."----
ggplot(data.frame(ichiro_random), aes(ichiro_random)) +
  geom_histogram(aes(y = stat(density)), bins = 20, 
                 color = crcblue, fill = "white") +
  geom_vline(xintercept = ichiro_S, size = 2) +
  annotate(geom = "text", x = ichiro_S * 1.15,
           y = 0.0010, label = "OBSERVED", size = 5) 

## ------------------------------------------------------------------------
quantile(ichiro_random, probs = 0:10/10)

## ------------------------------------------------------------------------
clump_test <- function(data, playerid) {
  data %>%
    filter(BAT_ID == playerid, AB_FL == TRUE) %>% 
    mutate(H = ifelse(H_FL > 0, 1, 0),
           DATE = substr(GAME_ID, 4, 12)) %>% 
    arrange(DATE)  -> player.AB 
  
  player.AB %>%
    pull(H) %>%
    streaks() %>% 
    filter(values == 0) %>% 
    summarize(C = sum(lengths ^ 2))  %>% 
    pull() -> stat
  
  ST <- replicate(1000, random_mix(player.AB$H))
  
  ggplot(data.frame(ST), aes(ST)) +
    geom_histogram(aes(y = stat(density)), bins = 20, 
                   color = crcblue, fill = "white") +
    geom_vline(xintercept = stat, size = 2) +
    annotate(geom = "text", x = stat * 1.10,
             y = 0.0010, label = "OBSERVED", size = 5)
}

## ----trout1, fig.cap="Histogram of one thousand values of the clumpiness statistic assuming all arrangements of hits and outs for the 2016 Mike Trout are equally likely. The observed value of the clumpiness statistic for Trout is shown using a vertical line."----
clump_test(data2016, "troum001")

## ----warning=FALSE-------------------------------------------------------
statcast2017 <- read_csv("../data/statcast2017.csv")
statcast2017 %>% 
  filter(type == "X") -> sc_ip2017
sc_ip2017 %>% 
  group_by(player_name, game_date) %>% 
  arrange(game_date) %>% 
  summarize(BIP = n(), 
            sum_LS = sum(launch_speed)) -> launch_speeds

## ------------------------------------------------------------------------
sc_ip2017 %>% 
  group_by(player_name) %>% 
  summarize(total_BIP = n()) %>%  
  filter(total_BIP >= 250) %>%
  inner_join(launch_speeds, by = "player_name") -> LS_250

## ------------------------------------------------------------------------
regroup <- function(data, group_size) {
  out <- data %>%
    mutate(id = row_number() - 1,
           group_id = floor(id / group_size))
    # hack to avoid a small leftover bin!
  if (nrow(data) %% group_size != 0) {
    max_group_id <- max(out$group_id)
    out <- out %>%
      mutate(group_id = ifelse(group_id == max_group_id, 
                               group_id - 1, group_id))
  }
  out %>%
    group_by(group_id) %>%
    summarize(G = n(), BIP = sum(BIP), sum_LS = sum(sum_LS))
}

## ------------------------------------------------------------------------
LS_250 %>%
  filter(player_name == "A.J. Pollock") %>% 
  arrange(game_date) -> aj
aj %>%
  regroup(5) -> x

## ------------------------------------------------------------------------
summarize_streak_data <- function(data, name, group_size = 5) {
  data %>%
    filter(player_name == name) %>% 
    arrange(game_date) %>%
    regroup(group_size) %>% 
    summarize(balls_in_play = sum(BIP),
              Mean = mean(sum_LS / BIP),
              SD = sd(sum_LS / BIP))
}

## ------------------------------------------------------------------------
aj_sum <- summarize_streak_data(LS_250, "A.J. Pollock")
aj_sum

## ------------------------------------------------------------------------
player_list <- LS_250 %>%
  pull(player_name) %>%
  unique()
Results <- player_list %>%
  map_df(summarize_streak_data, data = LS_250) %>%
  mutate(Player = player_list)

## ----scatter, fig.cap="Scatterplot of means and standard deviations of the five-game averages of launch speeds of regular players during the 2017 season.  The labeled points correspond to the players with the smallest and largest standard deviations, corresponding to consistent and streaky hitters."----
library(ggrepel)
ggplot(Results, aes(Mean, SD)) +
  geom_point() +
  geom_label_repel(
    data = filter(Results, SD > 5.63 | SD < 2.3 ),
    aes(label = Player))

## ------------------------------------------------------------------------
get_streak_data <- function(data, playername, group_size = 5) {
  data %>%
    filter(player_name == playername) %>% 
    arrange(game_date) %>%
    regroup(group_size) %>% 
    mutate(launch_speed_avg = sum_LS / BIP,
           Period = row_number())
}

## ----streak6, fig.cap="Line plots of five-game average launch velocities of Michael Conforto and Dexter Fowler for the 2017 season.  Conforto had a streaky pattern of launch velocities and Fowler's pattern is very consistent."----
streaky <- c("Michael Conforto", "Dexter Fowler") %>%
  set_names(.) %>%
  map_df(get_streak_data, data = LS_250, .id = "Player")

ggplot(streaky, aes(Period, launch_speed_avg)) +
  geom_line(size = 1) + 
  facet_wrap(~ Player, ncol = 1)

