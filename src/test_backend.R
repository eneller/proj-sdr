# =============================================================================
# test_backend.R
# Manual test of RTKPOS backend functions
# =============================================================================
# Usage:
#   1. source("test_backend.R")
#   2. Adjust file paths below to point to your RINEX test data
#   3. Run the script

# Source backend - try multiple locations
backend_sourced <- FALSE
for (p in c("src/rtkpos_backend.R", "rtkpos_backend.R")) {
  if (file.exists(p)) {
    source(p)
    backend_sourced <- TRUE
    break
  }
}
if (!backend_sourced) {
  stop("Cannot find rtkpos_backend.R. ",
       "Run from project root: source('src/test_backend.R')")
}

cat("========================================\n")
cat("RTKPOS Backend Test Suite\n")
cat("========================================\n\n")

# --- 1. Test default params ---
cat("[TEST] get_default_params() ... ")
params <- get_default_params()
stopifnot(is.list(params))
stopifnot(length(params) > 40)
cat("OK (", length(params), " parameters)\n")

# --- 2. Test config generation ---
cat("[TEST] generate_config() ... ")
config_file <- generate_config(params)
stopifnot(file.exists(config_file))
conf_lines <- readLines(config_file)
stopifnot(length(conf_lines) > 40)
cat("OK (", config_file, ")\n")

# --- 3. Test read_conf_file ---
cat("[TEST] read_conf_file() ... ")
params2 <- read_conf_file(config_file)
stopifnot(is.list(params2))
if (length(params2) != length(params)) {
  msg <- paste0(
    "Length mismatch: params=", length(params),
    " params2=", length(params2), "\n",
    "In params but not params2: ",
    paste(setdiff(names(params), names(params2)), collapse = ", "), "\n",
    "In params2 but not params: ",
    paste(setdiff(names(params2), names(params)), collapse = ", ")
  )
  stop(msg)
}
cat("OK (", length(params2), " parameters read)\n")

# --- 4. Test custom config ---
cat("[TEST] generate_config(custom) ... ")
custom_params <- list(
  "pos1-posmode"   = "kinematic",
  "pos1-frequency" = "l1+l2",
  "pos1-elmask"    = "10",
  "pos1-navsys"    = "5",
  "out-solformat"  = "llh",
  "out-outhead"    = "on"
)
custom_config <- generate_config(custom_params)
stopifnot(file.exists(custom_config))
cat("OK (", custom_config, ")\n")

# --- 5. Test parse with empty file ---
cat("[TEST] parse_rtkpos_output(empty) ... ")
empty_file <- tempfile(fileext = ".pos")
writeLines(c("% header line only", "% no data"), con = empty_file)
df_empty <- parse_rtkpos_output(empty_file)
stopifnot(nrow(df_empty) == 0)
cat("OK (0 rows)\n")

# --- 6. Test parse with simulated data ---
cat("[TEST] parse_rtkpos_output(simulated) ... ")
sim_file <- tempfile(fileext = ".pos")
sim_lines <- c(
  "% program  : RTKLIB ver. 2.4.3",
  "% obs start: 2026/01/15 00:00:00",
  "% (time)          (x)        (y)        (z)    (q)  (ns)  (sdx)  (sdy)  (sdz)",
  "2026/01/15 00:00:00.000  45.3271  14.4422  123.45  1    8   0.012  0.008  0.015",
  "2026/01/15 00:00:30.000  45.3272  14.4423  123.47  3    9   0.011  0.007  0.014",
  "2026/01/15 00:01:00.000  45.3273  14.4424  123.49  5   10   0.013  0.009  0.016"
)
writeLines(sim_lines, con = sim_file)
df_sim <- parse_rtkpos_output(sim_file)
stopifnot(nrow(df_sim) == 3)
stopifnot(colnames(df_sim)[1] == "time")
stopifnot(df_sim$Q[1] == 1)
stopifnot(df_sim$quality[2] == "fixed")
cat("OK (", nrow(df_sim), " rows, cols: ", paste(colnames(df_sim), collapse = ", "), ")\n")

# --- 7. Test plotting ---
cat("[TEST] plot_trajectory() ... ")
if (requireNamespace("ggplot2", quietly = TRUE)) {
  p1 <- plot_trajectory(df_sim)
  stopifnot(inherits(p1, "gg"))
  cat("OK\n")

  cat("[TEST] plot_height() ... ")
  p2 <- plot_height(df_sim)
  stopifnot(inherits(p2, "gg"))
  cat("OK\n")
} else {
  cat("SKIPPED (ggplot2 not installed)\n")
}

# --- 8. Test run_rtkpos (requires rnx2rtkp + RINEX data) ---
cat("\n[TEST] run_rtkpos() ... ")

# Auto-detect rnx2rtkp executable
rtkpos_exe <- Sys.which("rnx2rtkp")
if (rtkpos_exe == "") {
  candidates <- c(
    "C:/RTKLIB/bin/rnx2rtkp.exe",
    "C:/RTKLIB/RTKLIB_EX/bin/rnx2rtkp.exe",
    "C:/Program Files/RTKLIB/bin/rnx2rtkp.exe",
    "C:/RTKLIB-EX/bin/rnx2rtkp.exe"
  )
  for (candidate in candidates) {
    if (file.exists(candidate)) {
      rtkpos_exe <- candidate
      break
    }
  }
}

# Auto-detect RINEX data files in data/ directory
data_dir <- if (dir.exists("data")) "data" else "../data"
rover_file <- file.path(data_dir, "rover.obs")
nav_file   <- file.path(data_dir, "rover.nav")
base_file  <- file.path(data_dir, "tmg23590.20o")

# Try to find any .obs and .nav files if specific ones not found
if (!file.exists(rover_file)) {
  obs_files <- list.files(data_dir, pattern = "\\.(obs|OBS)$", full.names = TRUE)
  if (length(obs_files) > 0) rover_file <- obs_files[1]
}
if (!file.exists(nav_file)) {
  nav_files <- list.files(data_dir, pattern = "\\.(nav|NAV|eph|EPH|n|N)$", full.names = TRUE)
  if (length(nav_files) > 0) nav_file <- nav_files[1]
}

has_rtkpos <- nchar(rtkpos_exe) > 0 && file.exists(rtkpos_exe)
has_rover <- file.exists(rover_file)
has_nav   <- file.exists(nav_file)

if (!has_rtkpos) {
  cat("SKIPPED (rnx2rtkp not found)\n")
  cat("  Install RTKLIB from: https://github.com/rtklibexplorer/RTKLIB/releases\n")
  cat("  Or place rnx2rtkp.exe in PATH.\n")
} else if (!has_rover || !has_nav) {
  cat("SKIPPED (RINEX data not found in data/ directory)\n")
  cat("  Place RINEX .obs and .nav files in: ", normalizePath(data_dir), "\n")
  cat("  Expected: rover.obs + rover.nav (or any .obs + .nav pair)\n")
} else {
  base_arg <- if (file.exists(base_file)) base_file else NULL

  result <- run_rtkpos(
    rover_obs  = rover_file,
    nav_file   = nav_file,
    base_obs   = base_arg,
    posmode    = 0,
    elmask     = 15,
    rtkpos_exe = rtkpos_exe
  )

  if (result$exit_code == 0) {
    cat("OK (exit code 0)\n")
    cat("  Output:", result$output_file, "\n")

    if (file.exists(result$output_file)) {
      pos_df <- parse_rtkpos_output(result$output_file)
      cat("  Parsed:", nrow(pos_df), "epochs\n")
      if (nrow(pos_df) > 0) {
        cat("  Head:\n")
        print(utils::head(pos_df, 4))
      }
    }
  } else {
    cat("FAILED (exit code", result$exit_code, ")\n")
    cat("  Command:", result$command, "\n")
    cat("  stderr:\n")
    lines <- strsplit(result$stdout, "\n")[[1]]
    cat(tail(lines, 10), sep = "\n")
  }
}

cat("\n[TEST] All available tests completed.\n")
