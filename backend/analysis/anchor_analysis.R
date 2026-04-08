# Anchor R Analysis Layer
# Statistical functions for initiation analysis, energy clustering, and perception divergence.
# Called by the Node.js backend (via Plumber) or directly as child processes.

library(DBI)
library(RPostgres)

# ─── Database connection ──────────────────────────────────────────────────────

get_conn <- function() {
  dbConnect(
    RPostgres::Postgres(),
    dbname   = Sys.getenv("PGDATABASE", "anchor"),
    host     = Sys.getenv("PGHOST",     "localhost"),
    port     = as.integer(Sys.getenv("PGPORT", "5432")),
    user     = Sys.getenv("PGUSER",     "postgres"),
    password = Sys.getenv("PGPASSWORD", "")
  )
}

# ─── Initiation Analysis ──────────────────────────────────────────────────────
#
# Returns proportion test result: estimate, conf.int, p.value
# Answers: "Is there a statistically significant initiation imbalance?"

initiation_analysis <- function(person_id, conn = NULL) {
  close_conn <- is.null(conn)
  if (close_conn) conn <- get_conn()
  on.exit(if (close_conn) dbDisconnect(conn))

  rows <- dbGetQuery(conn,
    "SELECT initiated_by FROM interactions
     WHERE person_id = $1
       AND initiated_by != 'unclear'
     ORDER BY created_at DESC
     LIMIT 30",
    params = list(person_id)
  )

  n <- nrow(rows)
  if (n < 4) {
    return(list(
      estimate         = 0.5,
      conf_int_low     = 0.0,
      conf_int_high    = 1.0,
      p_value          = 1.0,
      n                = n,
      they_initiated   = 0L,
      statistically_significant = FALSE,
      message          = "Insufficient data (< 4 interactions)"
    ))
  }

  they_count <- sum(rows$initiated_by == "them")
  test <- prop.test(they_count, n, p = 0.5, alternative = "two.sided", correct = FALSE)

  list(
    estimate                  = unname(test$estimate),
    conf_int_low              = test$conf.int[1],
    conf_int_high             = test$conf.int[2],
    p_value                   = test$p.value,
    n                         = n,
    they_initiated            = they_count,
    you_initiated             = n - they_count,
    statistically_significant = test$p.value < 0.05,
    message                   = if (test$p.value < 0.05)
                                  sprintf("Significant imbalance: they initiate %.0f%% of the time (p=%.3f)",
                                          unname(test$estimate) * 100, test$p.value)
                                else
                                  "No statistically significant initiation imbalance"
  )
}

# ─── Energy Clustering ────────────────────────────────────────────────────────
#
# Groups people by average energy rating and interaction count.
# Returns cluster assignments and centroids.

energy_clustering <- function(user_id, conn = NULL) {
  close_conn <- is.null(conn)
  if (close_conn) conn <- get_conn()
  on.exit(if (close_conn) dbDisconnect(conn))

  data <- dbGetQuery(conn,
    "SELECT
       p.id         AS person_id,
       p.name       AS person_name,
       AVG(i.energy_rating)  AS avg_energy,
       COUNT(i.id)::int      AS interaction_count
     FROM interactions i
     JOIN persons p ON p.id = i.person_id
     WHERE i.user_id = $1
       AND i.energy_rating IS NOT NULL
     GROUP BY p.id, p.name
     HAVING COUNT(i.id) >= 2",
    params = list(user_id)
  )

  if (nrow(data) < 3) {
    return(list(
      clusters = data,
      message  = "Not enough people with energy data for clustering (need >= 3)"
    ))
  }

  k <- min(3, nrow(data))
  set.seed(42)
  km <- kmeans(
    scale(data[, c("avg_energy", "interaction_count")]),
    centers  = k,
    nstart   = 20,
    iter.max = 100
  )

  data$cluster <- km$cluster

  # Label clusters by average energy
  cluster_energies <- tapply(data$avg_energy, data$cluster, mean)
  sorted_clusters  <- order(cluster_energies)
  labels <- c("draining", "neutral", "energizing")
  cluster_labels <- setNames(labels[seq_along(sorted_clusters)], sorted_clusters)
  data$cluster_label <- cluster_labels[as.character(data$cluster)]

  list(
    clusters          = data,
    centroids         = as.data.frame(km$centers),
    within_ss         = km$tot.withinss,
    k                 = k,
    message           = sprintf("Clustered %d people into %d groups", nrow(data), k)
  )
}

# ─── Perception Divergence ────────────────────────────────────────────────────
#
# Compares perceived relationship score (1–5) to a reality score
# derived from behavioral metrics. Returns divergence magnitude and direction.

perception_divergence <- function(perceived, reality_metrics) {
  # reality_metrics: list(theyInitiatedRatio, secureFraction, totalInteractions)
  if (is.null(perceived) || is.na(perceived)) {
    return(list(error = "perceived score required"))
  }

  they_ratio   <- reality_metrics[["theyInitiatedRatio"]]  %||% 0.5
  secure_frac  <- reality_metrics[["secureFraction"]]       %||% 0.5
  n            <- reality_metrics[["totalInteractions"]]    %||% 0

  # Normalize behavioral signals to 1–5 scale
  # they_ratio: 0=you chase, 1=they chase → maps to 1–5
  # secure_frac: 0=all anxious, 1=all secure → maps to 1–5
  reality_score <- (they_ratio * 2.0 + secure_frac * 3.0)  # 0–5 raw
  reality_score <- max(1.0, min(5.0, reality_score))        # clamp

  divergence <- abs(perceived - reality_score)
  direction  <- if (perceived < reality_score) "underestimating" else "overestimating"
  flagged    <- divergence > 1.5

  list(
    reality_score = reality_score,
    perceived     = perceived,
    divergence    = divergence,
    direction     = direction,
    flagged       = flagged,
    n             = n,
    message       = if (flagged)
      sprintf("You're %s the relationship quality by %.1f points", direction, divergence)
    else
      "Perception and reality are reasonably aligned"
  )
}

# ─── Sentiment Significance Test ──────────────────────────────────────────────
#
# Tests whether a shift in sentiment proportions is statistically significant.

sentiment_shift_test <- function(person_id, conn = NULL) {
  close_conn <- is.null(conn)
  if (close_conn) conn <- get_conn()
  on.exit(if (close_conn) dbDisconnect(conn))

  now <- Sys.time()
  thirty_days_ago <- now - 30 * 24 * 3600
  sixty_days_ago  <- now - 60 * 24 * 3600

  recent <- dbGetQuery(conn,
    "SELECT sentiment FROM interactions
     WHERE person_id = $1
       AND created_at >= $2
       AND sentiment IS NOT NULL",
    params = list(person_id, thirty_days_ago)
  )

  prev <- dbGetQuery(conn,
    "SELECT sentiment FROM interactions
     WHERE person_id = $1
       AND created_at >= $2
       AND created_at < $3
       AND sentiment IS NOT NULL",
    params = list(person_id, sixty_days_ago, thirty_days_ago)
  )

  if (nrow(recent) < 3 || nrow(prev) < 3) {
    return(list(
      statistically_significant = FALSE,
      message = "Insufficient data for sentiment shift test"
    ))
  }

  recent_anxious <- sum(recent$sentiment == "anxious")
  prev_anxious   <- sum(prev$sentiment == "anxious")

  test <- prop.test(
    c(recent_anxious, prev_anxious),
    c(nrow(recent), nrow(prev)),
    alternative = "two.sided",
    correct = FALSE
  )

  list(
    recent_anxious_rate = recent_anxious / nrow(recent),
    prev_anxious_rate   = prev_anxious / nrow(prev),
    p_value             = test$p.value,
    statistically_significant = test$p.value < 0.05,
    message = if (test$p.value < 0.05)
      sprintf("Significant sentiment shift detected (p=%.3f)", test$p.value)
    else
      "No significant sentiment shift"
  )
}

# ─── Null-coalescing operator ─────────────────────────────────────────────────
`%||%` <- function(a, b) if (!is.null(a) && !is.na(a)) a else b
