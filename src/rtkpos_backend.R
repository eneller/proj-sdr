# =============================================================================
# rtkpos_backend.R
# RTKPOS post-processing GNSS SDR -- R backend
# =============================================================================
#
# Provides R functions to:
#   1. Generate RTKLIB configuration files
#   2. Call rnx2rtkp.exe (RTKPOS CLI tool) from R via system2()
#   3. Parse .pos output files into R data.frames
#   4. Visualize results with ggplot2
#
# Dependencies: ggplot2 (for plotting)
# For calling rnx2rtkp: requires RTKLIB installation
#
# Usage:
#   source("rtkpos_backend.R")
#   config <- generate_config(list("pos1-posmode" = "kinematic"))
#   result <- run_rtkpos("rover.obs", "nav.nav", config_file = config)
#   pos_df <- parse_rtkpos_output(result$output_file)
#   plot_trajectory(pos_df)
#
# =============================================================================


# =============================================================================
# SECTION 1: CONFIGURATION
# =============================================================================

#' @title Default RTKPOS configuration parameters
#' @return Named list of configuration key-value pairs (all as strings)

get_default_params <- function() {
  list(
    # --- POSITIONING OPTIONS (SETTING1) ---
    "pos1-posmode"    = "single",     # 0:single, 1:dgps, 2:kinematic, 3:static
    "pos1-frequency"  = "l1",         # 1:l1, 2:l1+l2, 3:l1+l2+l5
    "pos1-soltype"    = "forward",    # 0:forward, 1:backward, 2:combined
    "pos1-elmask"     = "15",         # elevation mask (deg)
    "pos1-snrmask"    = "off",        # SNR mask (dBHz)
    "pos1-dynamics"   = "off",        # 0:off, 1:on
    "pos1-tidecorr"   = "off",        # 0:off, 1:on
    "pos1-ionoopt"    = "brdc",       # 0:off, 1:brdc, 2:sbas, 3:dual-freq, 4:est-stec
    "pos1-tropopt"    = "saas",       # 0:off, 1:saas, 2:sbas, 3:est-ztd, 4:est-ztdgrad
    "pos1-sateph"     = "brdc",       # 0:brdc, 1:precise, 2:brdc+sbas
    "pos1-navsys"     = "1",          # bitmask: 1=gps, 2=sbas, 4=glo, 8=gal, 16=qzs, 32=bds
    "pos1-exclsats"   = "",           # excluded satellites (PRN list)

    # --- INTEGER AMBIGUITY RESOLUTION (SETTING2) ---
    "pos2-armode"     = "off",        # 0:off, 1:continuous, 2:instantaneous, 3:fix-and-hold
    "pos2-gloarmode"  = "off",        # 0:off, 1:on, 2:autocal
    "pos2-arthres"    = "3",          # AR threshold (0..3)
    "pos2-arlockcnt"  = "0",          # lock count for AR
    "pos2-arelmask"   = "0",          # elevation mask for AR (deg)
    "pos2-arminfix"   = "0",          # minimum fix count
    "pos2-aroutcnt"   = "0",          # AR output counter
    "pos2-maxage"     = "30",         # max age of differential data (s)

    # --- OUTPUT FORMAT ---
    "out-solformat"   = "llh",        # 0:llh, 1:xyz, 2:enu, 3:nmea
    "out-outhead"     = "on",         # output header
    "out-outopt"      = "on",         # output options
    "out-timesys"     = "gpst",       # 0:gpst, 1:utc, 2:jst
    "out-timeform"    = "hms",        # 0:tow, 1:hms
    "out-timendec"    = "3",          # decimals in time
    "out-degform"     = "deg",        # 0:deg, 1:dms
    "out-fieldsep"    = " ",          # field separator
    "out-height"      = "ellipsoidal",# 0:ellipsoidal, 1:geodetic
    "out-solstatic"   = "all",        # 0:all, 1:single

    # --- STATISTICS ---
    "stats-errratio"  = "100",        # code/carrier error ratio
    "stats-errphase"  = "0.003",      # carrier phase error std (m)
    "stats-errphaseel"= "0.003",      # carrier phase err std elev-dep (m)
    "stats-errdoppler"= "1",          # doppler frequency error std (Hz)
    "stats-stdbias"   = "30",         # code bias std (m)
    "stats-stdiono"   = "0.03",       # ionospheric std (m)
    "stats-stdtrop"   = "0.3",        # tropospheric std (m)
    "stats-prnaccelh" = "1",          # process noise accel horiz (m/s^2)
    "stats-prnaccelv" = "0.1",        # process noise accel vert (m/s^2)

    # --- ANTENNA 1 (rover) ---
    "ant1-postype"    = "llh",
    "ant1-pos1"       = "0",
    "ant1-pos2"       = "0",
    "ant1-pos3"       = "0",
    "ant1-antdele"    = "0",
    "ant1-antdeln"    = "0",
    "ant1-antdelu"    = "0",

    # --- ANTENNA 2 (base) ---
    "ant2-postype"    = "single",
    "ant2-pos1"       = "0",
    "ant2-pos2"       = "0",
    "ant2-pos3"       = "0",
    "ant2-antdele"    = "0",
    "ant2-antdeln"    = "0",
    "ant2-antdelu"    = "0"
  )
}


#' @title Generate RTKLIB configuration file
#' @param params Named list of config parameters (key = value)
#' @param filepath Path to output .conf file. If NULL, uses tempfile().
#' @return Path to the generated config file (invisible)

generate_config <- function(params = NULL, filepath = NULL) {
  if (is.null(params)) {
    params <- get_default_params()
  }

  if (is.null(filepath)) {
    filepath <- tempfile(pattern = "rtkpos_", fileext = ".conf")
  }

  dir.create(dirname(filepath), showWarnings = FALSE, recursive = TRUE)

  lines <- character(length(params))
  i <- 1
  for (key in names(params)) {
    value <- params[[key]]
    # Use paste0 to avoid ambiguous trailing whitespace in sprintf
    lines[i] <- paste0(key, "=", value)
    i <- i + 1
  }

  header <- c(
    "# RTKLIB config generated by rtkpos_backend.R",
    paste("# Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    ""
  )

  writeLines(c(header, lines), con = filepath)
  invisible(filepath)
}


#' @title Read RTKLIB configuration file into a named list
#' @param filepath Path to .conf file
#' @return Named list of configuration parameters (all as strings)

read_conf_file <- function(filepath) {
  if (!file.exists(filepath)) {
    stop("Config file not found: ", filepath)
  }

  lines <- readLines(filepath, warn = FALSE)
  params <- list()

  for (line in lines) {
    # Skip comments and blank lines (check BEFORE trimws)
    if (nchar(line) == 0) next

    first_char <- substr(trimws(line), 1, 1)
    if (first_char == "#") next

    # Find the FIRST "=" sign (key may contain hyphens but not equals)
    eq_pos <- regexpr("=", line)
    if (eq_pos == -1) next

    # Extract key (trimmed) and value (everything after first "=")
    key   <- trimws(substr(line, 1, eq_pos - 1))
    value <- substr(line, eq_pos + 1, nchar(line))

    # Remove inline comments (RTKLIB uses # for comments)
    comment_pos <- regexpr("#", value)
    if (comment_pos > 0) {
      value <- substr(value, 1, comment_pos - 1)
    }

    # Remove leading and trailing whitespace from value
    value <- trimws(value)

    params[[key]] <- value
  }

  return(params)
}


# =============================================================================
# SECTION 2: EXECUTION
# =============================================================================

#' @title Run RTKPOS post-processing
#' @param rover_obs Path to rover RINEX OBS file (required)
#' @param nav_file  Path to RINEX NAV/EPH file (required)
#' @param base_obs  Path to base station RINEX OBS file (optional)
#' @param config_file Path to config file. If NULL, auto-generated.
#' @param output_file Path for output .pos file. If NULL, tempfile() used.
#' @param posmode  Positioning mode: 0=single, 1=dgps, 2=kinematic, 3=static
#' @param elmask   Elevation mask in degrees
#' @param rtkpos_exe Path to rnx2rtkp executable. If NULL, auto-detected.
#' @return List with: exit_code, stdout, output_file, config_file, command

run_rtkpos <- function(rover_obs,
                       nav_file,
                       base_obs    = NULL,
                       config_file = NULL,
                       output_file = NULL,
                       posmode     = 0,
                       elmask      = 15,
                       rtkpos_exe  = NULL) {

  # --- 1. Detect rnx2rtkp executable ---
  if (is.null(rtkpos_exe)) {
    rtkpos_exe <- Sys.which("rnx2rtkp")
    if (rtkpos_exe == "") {
      candidates <- c(
        "C:/RTKLIB/bin/rnx2rtkp.exe",
        "C:/RTKLIB/RTKLIB_EX/bin/rnx2rtkp.exe",
        "C:/Program Files/RTKLIB/bin/rnx2rtkp.exe",
        "C:/RTKLIB-EX/bin/rnx2rtkp.exe",
        "../RTKLIB/bin/rnx2rtkp"
      )
      for (candidate in candidates) {
        if (file.exists(candidate)) {
          rtkpos_exe <- candidate
          break
        }
      }
    }
    if (rtkpos_exe == "") {
      stop(
        "rnx2rtkp executable not found.\n",
        "Install RTKLIB from: https://github.com/rtklibexplorer/RTKLIB/releases\n",
        "Or provide the full path via the 'rtkpos_exe' argument."
      )
    }
  }

  if (!file.exists(rtkpos_exe)) {
    stop("rnx2rtkp executable not found at: ", rtkpos_exe)
  }

  # --- 2. Validate input files ---
  required_files <- c(rover_obs, nav_file)
  missing <- required_files[!file.exists(required_files)]
  if (length(missing) > 0) {
    stop("Required input files not found:\n  ",
         paste(missing, collapse = "\n  "))
  }

  # --- 3. Auto-generate config if not provided ---
  if (is.null(config_file)) {
    params <- get_default_params()
    params[["pos1-posmode"]] <- as.character(posmode)
    params[["pos1-elmask"]]  <- as.character(elmask)
    if (posmode >= 2) {
      params[["pos1-frequency"]] <- "l1+l2"
      params[["pos2-armode"]]    <- "continuous"
    }
    config_file <- generate_config(params)
  }

  # --- 4. Set output file ---
  if (is.null(output_file)) {
    output_file <- tempfile(pattern = "rtkpos_", fileext = ".pos")
  }
  dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)

  # --- 5. Build command arguments ---
  # NOTE: -o is intentionally omitted; position output is captured from stdout
  args <- c(
    "-k", shQuote(config_file),
    "-p", as.character(posmode),
    "-m", as.character(elmask),
    "-t",
    "-d", "3",
    shQuote(rover_obs)
  )

  if (!is.null(base_obs) && file.exists(base_obs)) {
    args <- c(args, shQuote(base_obs))
  }

  args <- c(args, shQuote(nav_file))

  # --- 6. Execute via system2 ---
  message(">>> RTKPOS command:")
  message("  ", rtkpos_exe, " ", paste(args, collapse = " "))

  proc_result <- tryCatch(
    suppressWarnings(
      system2(
        command = rtkpos_exe,
        args    = args,
        stdout  = TRUE,
        stderr  = TRUE,
        wait    = TRUE
      )
    ),
    error = function(e) {
      list(stdout = "", stderr = paste("Error:", e$message), status = -1)
    }
  )

  if (is.list(proc_result)) {
    ec <- attr(proc_result, "status")
    exit_code   <- if (is.null(ec)) -1 else ec
    so <- proc_result[["stdout"]]
    raw_stdout  <- if (is.null(so)) character(0) else so
    se <- proc_result[["stderr"]]
    stderr_text <- if (is.null(se)) "" else paste(se, collapse = "\n")
  } else {
    ec <- attr(proc_result, "status")
    exit_code   <- if (is.null(ec)) 0 else ec
    raw_stdout  <- if (is.null(proc_result)) character(0) else proc_result
    stderr_text <- ""
  }

  # --- 7. Filter progress lines from stdout, write position data to file ---
  # rnx2rtkp prints "processing : ..." progress lines to stdout
  # Actual position data lines start with a date (yyyy/mm/dd)
  pos_lines <- grep("^[0-9]{4}/[0-9]{2}/[0-9]{2}", raw_stdout, value = TRUE)
  stdout_text <- paste(raw_stdout, collapse = "\n")

  if (length(pos_lines) > 0) {
    writeLines(pos_lines, con = output_file)
  }

  if (exit_code != 0 || length(pos_lines) == 0) {
    warning("RTKPOS processing may have failed. Exit code: ", exit_code,
            " | Epochs: ", length(pos_lines))
  }

  # --- 8. Return structured result ---
  result <- list(
    exit_code   = exit_code,
    stdout      = stdout_text,
    stderr      = stderr_text,
    output_file = output_file,
    config_file = config_file,
    epochs      = length(pos_lines),
    command     = paste(shQuote(rtkpos_exe), paste(args, collapse = " "))
  )

  class(result) <- "rtkpos_result"
  return(result)
}


#' @title Print method for rtkpos_result
#' @param x rtkpos_result object
#' @param ... Additional arguments (ignored)

print.rtkpos_result <- function(x, ...) {
  cat("RTKPOS Result\n")
  cat("  Exit code :", x$exit_code, "\n")
  cat("  Output    :", x$output_file, "\n")
  cat("  Config    :", x$config_file, "\n")
  if (file.exists(x$output_file)) {
    sz <- file.info(x$output_file)$size
    cat("  Size      :", sz, "bytes\n")
  }
  cat("--- stdout (last 20 lines) ---\n")
  lines <- strsplit(x$stdout, "\n")[[1]]
  cat(tail(lines, 20), sep = "\n")
  cat("\n")
}


# =============================================================================
# SECTION 3: PARSING
# =============================================================================

#' @title Parse RTKPOS .pos output file
#' @param filepath Path to .pos file generated by rnx2rtkp
#' @return data.frame with columns: time, lat, lon, hgt, Q, quality, ns, sdx, sdy, sdz

parse_rtkpos_output <- function(filepath) {
  if (!file.exists(filepath)) {
    stop("Output file not found: ", filepath)
  }

  lines <- readLines(filepath, warn = FALSE)

  data_lines <- lines[!grepl("^\\s*%", lines)]
  data_lines <- data_lines[nchar(trimws(data_lines)) > 0]

  if (length(data_lines) == 0) {
    message("(no data rows in ", basename(filepath), ")")
    return(data.frame(
      time    = as.POSIXct(character()),
      lat     = numeric(),
      lon     = numeric(),
      hgt     = numeric(),
      Q       = integer(),
      quality = character(),
      ns      = integer(),
      sdx     = numeric(),
      sdy     = numeric(),
      sdz     = numeric(),
      stringsAsFactors = FALSE
    ))
  }

  # Time with -t flag is "yyyy/mm/dd hh:mm:ss.sss" (two whitespace tokens)
  # We must parse manually since read.table splits on whitespace
  n <- length(data_lines)
  time_vec <- character(n)
  lat_vec  <- numeric(n)
  lon_vec  <- numeric(n)
  hgt_vec  <- numeric(n)
  Q_vec    <- integer(n)
  ns_vec   <- integer(n)
  sdx_vec  <- numeric(n)
  sdy_vec  <- numeric(n)
  sdz_vec  <- numeric(n)

  for (i in seq_len(n)) {
    tokens <- strsplit(trimws(data_lines[i]), "\\s+")[[1]]

    # Expected pattern:
    # date(1) + time(2) + lat(3) + lon(4) + hgt(5) + Q(6) + ns(7) + sdx(8) + sdy(9) + sdz(10)
    if (length(tokens) < 10) next

    time_vec[i] <- paste(tokens[1], tokens[2])
    lat_vec[i]  <- as.numeric(tokens[3])
    lon_vec[i]  <- as.numeric(tokens[4])
    hgt_vec[i]  <- as.numeric(tokens[5])
    Q_vec[i]    <- as.integer(tokens[6])
    ns_vec[i]   <- as.integer(tokens[7])
    sdx_vec[i]  <- as.numeric(tokens[8])
    sdy_vec[i]  <- as.numeric(tokens[9])
    sdz_vec[i]  <- as.numeric(tokens[10])
  }

  raw <- data.frame(
    time_str = time_vec,
    lat      = lat_vec,
    lon      = lon_vec,
    hgt      = hgt_vec,
    Q        = Q_vec,
    ns       = ns_vec,
    sdx      = sdx_vec,
    sdy      = sdy_vec,
    sdz      = sdz_vec,
    stringsAsFactors = FALSE
  )

  # Remove rows that failed to parse (NA in lat)
  raw <- raw[!is.na(raw$lat), ]

  raw$time <- as.POSIXct(raw$time_str, format = "%Y/%m/%d %H:%M:%OS",
                         tz = "GMT")

  quality_map <- c(
    "1" = "float",      "2" = "float",
    "3" = "fixed",      "4" = "fixed",
    "5" = "single",
    "6" = "dgps",
    "7" = "ppp_kine",
    "8" = "ppp_static"
  )
  raw$quality <- quality_map[as.character(raw$Q)]
  raw$quality[is.na(raw$quality)] <- "unknown"

  result <- raw[, c("time", "lat", "lon", "hgt", "Q", "quality",
                    "ns", "sdx", "sdy", "sdz")]
  rownames(result) <- NULL

  return(result)
}


# =============================================================================
# SECTION 4: VISUALIZATION
# =============================================================================

#' @title Plot 2D trajectory from parsed RTKPOS output
#' @param pos_df data.frame from parse_rtkpos_output()
#' @param color_by Column to color points by: "Q", "quality", "ns", "hgt"
#' @return ggplot2 object

plot_trajectory <- function(pos_df, color_by = "Q") {
  if (nrow(pos_df) == 0) {
    p <- ggplot2::ggplot() +
      ggplot2::ggtitle("No data to plot") +
      ggplot2::theme_minimal()
    return(p)
  }

  is_numeric <- is.numeric(pos_df[[color_by]])

  p <- ggplot2::ggplot(pos_df, ggplot2::aes(x = lon, y = lat,
                                              color = .data[[color_by]])) +
    ggplot2::geom_path(alpha = 0.4, linewidth = 0.5) +
    ggplot2::geom_point(size = 1.8, alpha = 0.8)

  if (is_numeric) {
    p <- p + ggplot2::scale_color_viridis_c(option = "turbo")
  } else {
    p <- p + ggplot2::scale_color_viridis_d(option = "turbo")
  }

  p <- p +
    ggplot2::coord_quickmap() +
    ggplot2::labs(
      title    = "Receiver Trajectory",
      subtitle = paste(nrow(pos_df), "epochs"),
      x        = "Longitude (deg)",
      y        = "Latitude (deg)",
      color    = color_by
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = ggplot2::element_text(hjust = 0.5, size = 9)
    )

  return(p)
}


#' @title Plot height over time from parsed RTKPOS output
#' @param pos_df data.frame from parse_rtkpos_output()
#' @return ggplot2 object

plot_height <- function(pos_df) {
  if (nrow(pos_df) == 0) {
    p <- ggplot2::ggplot() +
      ggplot2::ggtitle("No data to plot") +
      ggplot2::theme_minimal()
    return(p)
  }

  p <- ggplot2::ggplot(pos_df,
                        ggplot2::aes(x = time, y = hgt,
                                     color = as.factor(Q))) +
    ggplot2::geom_line(alpha = 0.6, linewidth = 0.5) +
    ggplot2::geom_point(size = 1.5, alpha = 0.8) +
    ggplot2::scale_color_viridis_d(option = "turbo") +
    ggplot2::labs(
      title = "Height Over Time",
      x     = "Time (GPST)",
      y     = "Height (m)",
      color = "Quality (Q)"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold")
    )

  return(p)
}
