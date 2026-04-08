# Anchor R Analysis Layer
# Exposes statistical endpoints consumed by the Node.js Critic/Perception engines.

suppressPackageStartupMessages({
  library(plumber)
  library(jsonlite)
})

safe_require <- function(pkg) {
  suppressWarnings(require(pkg, character.only = TRUE, quietly = TRUE))
}

has_dbi <- safe_require('DBI')
has_rpostgres <- safe_require('RPostgres')

connect_db <- function() {
  if (!has_dbi || !has_rpostgres) {
    return(NULL)
  }

  database_url <- Sys.getenv('DATABASE_URL')
  if (database_url == '') {
    return(NULL)
  }

  tryCatch(
    DBI::dbConnect(RPostgres::Postgres(), dbname = database_url),
    error = function(e) NULL
  )
}

with_db <- function(fn) {
  conn <- connect_db()
  on.exit({
    if (!is.null(conn)) {
      try(DBI::dbDisconnect(conn), silent = TRUE)
    }
  })
  fn(conn)
}

compute_initiation <- function(initiated_by) {
  if (length(initiated_by) == 0) {
    return(list(
      validated = FALSE,
      they_initiated_ratio = 0.5,
      sample_size = 0,
      p_value = NA,
      conf_int_low = NA,
      conf_int_high = NA
    ))
  }

  clean <- initiated_by[initiated_by %in% c('them', 'user')]
  n <- length(clean)
  if (n == 0) {
    return(list(
      validated = FALSE,
      they_initiated_ratio = 0.5,
      sample_size = 0,
      p_value = NA,
      conf_int_low = NA,
      conf_int_high = NA
    ))
  }

  them_count <- sum(clean == 'them')
  ratio <- them_count / n
  test <- suppressWarnings(prop.test(them_count, n, p = 0.5))

  list(
    validated = n >= 6 && !is.na(test$p.value) && test$p.value < 0.1,
    they_initiated_ratio = ratio,
    sample_size = n,
    p_value = as.numeric(test$p.value),
    conf_int_low = as.numeric(test$conf.int[1]),
    conf_int_high = as.numeric(test$conf.int[2])
  )
}

compute_energy_clusters <- function(df) {
  if (nrow(df) < 3) {
    return(list(validated = FALSE, clusters = list(), reason = 'not enough people for clustering'))
  }

  feature <- df[, c('avg_energy', 'interaction_count')]
  feature$avg_energy[is.na(feature$avg_energy)] <- 0
  feature$interaction_count[is.na(feature$interaction_count)] <- 0

  km <- kmeans(feature, centers = 3)
  out <- split(
    data.frame(person_id = df$person_id, cluster = km$cluster),
    km$cluster
  )

  clusters <- lapply(out, function(tbl) {
    list(
      cluster = as.integer(tbl$cluster[1]),
      person_ids = as.character(tbl$person_id)
    )
  })

  list(validated = TRUE, clusters = clusters)
}

normalize_to_scale <- function(reality_metrics) {
  initiation <- ifelse(is.null(reality_metrics$initiationRatio), 0.5, reality_metrics$initiationRatio)
  consistency <- ifelse(is.null(reality_metrics$consistencyScore), 0.5, reality_metrics$consistencyScore)
  follow <- ifelse(is.null(reality_metrics$followThroughRate), 0.5, reality_metrics$followThroughRate)
  trend <- ifelse(is.null(reality_metrics$energyTrend), 0, reality_metrics$energyTrend)

  trend_scaled <- max(0, min(1, (trend + 0.2) / 0.4))
  weighted <- initiation * 0.35 + consistency * 0.25 + follow * 0.25 + trend_scaled * 0.15
  score <- 1 + weighted * 4
  max(1, min(5, score))
}

#* Health
#* @get /health
function() {
  list(ok = TRUE, service = 'anchor-r-analysis')
}

#* Initiation ratio with confidence interval
#* @post /initiation-analysis
#* @serializer json list(na = "null", auto_unbox = TRUE)
function(req, res) {
  body <- tryCatch(fromJSON(req$postBody), error = function(e) list())

  result <- with_db(function(conn) {
    if (is.null(conn) || is.null(body$personId)) {
      initiated <- if (!is.null(body$initiatedBy)) body$initiatedBy else c()
      return(compute_initiation(initiated))
    }

    query <- paste(
      "SELECT initiated_by FROM interactions",
      "WHERE person_id = $1 ORDER BY created_at DESC LIMIT 30"
    )

    interactions <- tryCatch(
      DBI::dbGetQuery(conn, query, params = list(body$personId)),
      error = function(e) data.frame(initiated_by = character(0))
    )

    compute_initiation(interactions$initiated_by)
  })

  result
}

#* Energy clustering — who drains vs energizes
#* @post /energy-clustering
#* @serializer json list(na = "null", auto_unbox = TRUE)
function(req, res) {
  body <- tryCatch(fromJSON(req$postBody), error = function(e) list())

  result <- with_db(function(conn) {
    if (is.null(conn) || is.null(body$userId)) {
      if (is.null(body$records)) {
        return(list(validated = FALSE, clusters = list(), reason = 'no DB and no records payload'))
      }
      df <- as.data.frame(body$records)
      return(compute_energy_clusters(df))
    }

    query <- paste(
      "SELECT person_id, AVG(COALESCE(energy_rating, 0)) AS avg_energy,",
      "COUNT(*) AS interaction_count",
      "FROM interactions WHERE user_id = $1 GROUP BY person_id"
    )

    data <- tryCatch(
      DBI::dbGetQuery(conn, query, params = list(body$userId)),
      error = function(e) data.frame(person_id = character(0), avg_energy = numeric(0), interaction_count = integer(0))
    )

    compute_energy_clusters(data)
  })

  result
}

#* Perception vs reality divergence score
#* @post /perception-divergence
#* @serializer json list(na = "null", auto_unbox = TRUE)
function(req, res) {
  body <- tryCatch(fromJSON(req$postBody), error = function(e) list())
  perceived <- ifelse(is.null(body$perceived), NA, as.numeric(body$perceived))

  reality_metrics <- if (!is.null(body$realityMetrics)) body$realityMetrics else list()
  reality_score <- normalize_to_scale(reality_metrics)

  if (is.na(perceived)) {
    return(list(
      validated = FALSE,
      reality_score = reality_score,
      divergence = NA,
      direction = 'unknown'
    ))
  }

  divergence <- abs(perceived - reality_score)
  direction <- ifelse(perceived < reality_score, 'underestimating', 'overestimating')

  list(
    validated = TRUE,
    reality_score = reality_score,
    divergence = divergence,
    direction = direction
  )
}

pr <- plumber::plumb()
pr$run(host = '0.0.0.0', port = as.integer(Sys.getenv('R_PORT', '8000')))
