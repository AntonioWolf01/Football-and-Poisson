# Load required libraries
library(rvest) #To scrape our data from the Fbref website
library(dplyr) #To calculate our strength ratings
library(ggplot2) #To create the heat map that will visually display our values
library(reshape2) #To convert a data frame to a melted format

# Set the URL from Fbref website
url = 'https://fbref.com/en/comps/11/schedule/Serie-A-Scores-and-Fixtures'

# Read HTML table from the URL
serieA_list = url %>%
  read_html() %>%
  html_nodes("table") %>%
  html_table(fill = TRUE) %>%
  .[[1]]

# View column names 
colnames(serieA_list)

# Now, let's perform the manipulation on our data set to obtain clean and relevant information

# Drop games that have no date
serieA_df = subset(serieA_list, !is.na(Wk))

# The data frame displays two columns both named 'xG', one for the home team and one for the away team
# Let's create a distinction
names(serieA_df)[names(serieA_df) == "xG"] = "xGHome" #Rename both 'xGHome'
second_xG <- which(names(serieA_df) == "xGHome")[2] #Select the second 'xGHome', representing our away team
names(serieA_df)[second_xG] = "xGAway" # Rename the second 'xGHome' column to 'xGAway'

# From 'Score' column, let's create two columns representing Home Score and Away Score
serieA_df$HomeScore = substr(serieA_df$Score, 1, 1)
serieA_df$AwayScore = substr(serieA_df$Score, 3, 3)

# Convert 'Date' column to Date type
serieA_df$Date = as.Date(serieA_df$Date)

# Sort by 'Date' column
serieA_df = serieA_df[order(serieA_df$Date), ]


# Reorder the data frame
serieA_df = serieA_df[, c('Wk', 'Day', 'Date', 'Time', 'Home', 'HomeScore', 'xGHome', 'AwayScore', 'xGAway', 'Away', 'Attendance', 'Venue', 'Referee')]

# Drop rows with missing values
serieA_df = serieA_df[complete.cases(serieA_df), ]

# Show only relevant columns
serieA_df = serieA_df[, c('Date', 'Home', 'HomeScore', 'xGHome', 'AwayScore', 'xGAway', 'Away')]
serieA_df = serieA_df[order(serieA_df$Date), ]
rownames(serieA_df) = NULL

# Now we can have a look on our final data set
# It contains in a clear format all the data we will work upon
serieA_df

# Calculate the home and away expected goals mean for the whole league
league_Mean_Home_xG = round(mean(serieA_df$'xGHome', na.rm = TRUE), 2)
league_Mean_Away_xG = round(mean(serieA_df$'xGAway', na.rm = TRUE), 2)

# We can also print them if we are curious
cat("The mean home expected goals is:", league_Mean_Home_xG, "\n")
cat("The mean away expected goals is:", league_Mean_Away_xG, "\n")


# Let's group and calculate offensive strength ratings for home teams 
home_team_xg_strength_offense = serieA_df %>%
  group_by(Home) %>%
  summarise(
    xGHome = sum(xGHome, na.rm = TRUE),
    TotalGames = n(),
    Home = first(Home)
  ) %>%
  ungroup() %>%
  mutate(
    xGHome_offense_rating = (xGHome / TotalGames) / league_Mean_Home_xG
  ) %>%
  arrange(desc(xGHome_offense_rating)) %>%
  select(Home, xGHome, TotalGames, xGHome_offense_rating)

# Print the resulting offensive strength ratings for home teams to see the result
print(home_team_xg_strength_offense)

# Now we repeat the process to find the other ratings

# Away offensive strength rating
away_team_xg_strength_offense = serieA_df %>%
  group_by(Away) %>%
  summarise(
    xGAway = sum(xGAway, na.rm = TRUE),
    TotalGames = n(),
    Away = first(Away)
  ) %>%
  ungroup() %>%
  mutate(
    xGAway_offense_rating = (xGAway / TotalGames) / league_Mean_Away_xG
  ) %>%
  arrange(desc(xGAway_offense_rating)) %>%
  select(Away, xGAway, TotalGames, xGAway_offense_rating)

# Print the result
print(away_team_xg_strength_offense)

# Home defensive strength rating
home_team_xg_strength_defence = serieA_df %>%
  group_by(Home) %>%
  summarise(
    xG_Conceded = sum(xGAway, na.rm = TRUE),
    TotalGames = n(),
    Home = first(Home)
  ) %>%
  ungroup() %>%
  mutate(
    xG_home_defense_rating = (xG_Conceded / TotalGames) / league_Mean_Away_xG
  ) %>%
  arrange(xG_home_defense_rating) %>%
  select(Home, xG_Conceded, TotalGames, xG_home_defense_rating)

# Print the result
print(home_team_xg_strength_defence)

# Away defensive strength rating
away_team_xg_strength_defence = serieA_df %>%
  group_by(Away) %>%
  summarise(
    xG_Conceded = sum(xGHome, na.rm = TRUE),
    TotalGames = n(),
    Away = first(Away)
  ) %>%
  ungroup() %>%
  mutate(
    xG_away_defense_rating = (xG_Conceded / TotalGames) / league_Mean_Home_xG
  ) %>%
  arrange(xG_away_defense_rating) %>%
  select(Away, xG_Conceded, TotalGames, xG_away_defense_rating)

# Print the result
print(away_team_xg_strength_defence)

# Given ratings for home team's offense and away team's defense
home_offense_rating = 1.0555556
away_defense_rating = 0.5833333
away_offense_rating = 1.5940367
home_defense_rating = 0.6766055

# Calculate home team's expected xG
home_expected_xg = (home_offense_rating * away_defense_rating) * league_Mean_Home_xG
home_expected_xg

# Calculate away team's expected xG
away_expected_xg = (away_offense_rating * home_defense_rating) * league_Mean_Away_xG
away_expected_xg

# Now we will assume that xG follow a Poisson distribution

# Assign a range of maximum goals scored 
max_score = 10
score_range = 0:max_score

# Calculate the pmf using Poisson distribution of home and away expected xG 
home_pmf = dpois(score_range, lambda = home_expected_xg)
away_pmf = dpois(score_range, lambda = away_expected_xg)

# Calculate outer product of home and away pmfs to obtain the combination of different results
score_matrix = outer(home_pmf, away_pmf)

# Create a square matrix with the different score combination
score_matrix = matrix(score_matrix, nrow = max_score + 1, ncol = max_score + 1)

# Convert the data frame to a long format
data_long <- melt(score_matrix)

# Use the ggplot library to create the heat map
score_heatmap = ggplot(data_long, aes(x = Var2 - 0.5, y = Var1 - 0.5, fill = value)) +
  geom_tile() +
  geom_text(aes(label = round(value, 3)), color = "black", size = 4) +
  scale_fill_gradient(low = "green", high = "red") +
  theme_minimal() +
  labs(x = "Away goals", y = "Home goals", title = "Score Matrix") +
  scale_x_continuous(breaks = seq(-0.5, max(data_long$Var2), by = 1), labels = function(x) floor(x)) +
  scale_y_continuous(breaks = seq(-0.5, max(data_long$Var1), by = 1), labels = function(x) floor(x))
score_heatmap #Print the heat map inside R environment

# Export the heat map as an image
ggsave("score_heatmap.png", plot = score_heatmap, width = 2400, height = 1600, dpi = 300, units = "px")