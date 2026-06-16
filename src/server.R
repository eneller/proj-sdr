# =============================================================================
# server.R - Shiny server for RTKPOS Post-Processing
# =============================================================================

server <- function(input, output, session) {

  # --- Reactive state ---
  rv <- reactiveValues(
    result = NULL,
    data   = NULL,
    status = "Ready"
  )

  # --- Helper: build params list from UI inputs ---
  build_params <- function() {
    params <- get_default_params()
    params[["pos1-posmode"]] <- input$pos1_posmode
    params[["pos1-elmask"]]  <- as.character(input$pos1_elmask)
    navsys <- input$pos1_navsys
    params[["pos1-navsys"]]  <- if (length(navsys) > 0) as.character(sum(as.integer(navsys))) else "1"
    params[["pos2-armode"]]  <- input$pos2_armode
    params[["out-solformat"]] <- input$out_solformat
    params[["out-timesys"]]  <- input$out_timesys
    params[["out-height"]]   <- input$out_height
    params
  }

  # --- Has data indicator for conditionalPanel ---
  output$has_data <- reactive({
    !is.null(rv$data) && nrow(rv$data) > 0
  })
  outputOptions(output, "has_data", suspendWhenHidden = FALSE)

  # --- Status output ---
  output$run_status <- renderText({
    rv$status
  })

  # --- Run button handler ---
  observeEvent(input$run_btn, {

    # ---- Validate inputs ----
    if (is.null(input$rover_file)) {
      showNotification("Please select a Rover OBS file.", type = "error")
      return()
    }
    if (is.null(input$nav_file)) {
      showNotification("Please select a Navigation file.", type = "error")
      return()
    }
    if (!file.exists(input$rover_file$datapath)) {
      showNotification("Rover OBS file not found.", type = "error")
      return()
    }
    if (!file.exists(input$nav_file$datapath)) {
      showNotification("Navigation file not found.", type = "error")
      return()
    }

    # Determine positioning mode
    posmode_val <- switch(input$pos1_posmode,
      "single" = 0, "dgps" = 1, "kinematic" = 2, "static" = 3)
    has_base <- !is.null(input$base_file) && file.exists(input$base_file$datapath)

    # Validate base requirement
    if (posmode_val >= 2 && !has_base) {
      showNotification(
        paste("Positioning mode", input$pos1_posmode,
              "requires a Base Station OBS file."),
        type = "error"
      )
      return()
    }

    # ---- Build params ---
    params <- build_params()
    rv$status <- "Generating config..."
    rv$result <- NULL
    rv$data <- NULL

    # ---- Process ----
    result <- NULL
    df <- NULL

    tryCatch({
      withProgress(
        message = "Processing...", value = 0, {

          incProgress(0.1, detail = "Generating config")
          config_file <- generate_config(params)

          incProgress(0.2, detail = "Running RTKPOS")

          # Normalize paths to use backslashes on Windows
          rover_path <- normalizePath(input$rover_file$datapath, winslash = "\\")
          nav_path   <- normalizePath(input$nav_file$datapath, winslash = "\\")
          base_path  <- if (has_base) normalizePath(input$base_file$datapath, winslash = "\\") else NULL

          result <- run_rtkpos(
            rover_obs  = rover_path,
            nav_file   = nav_path,
            base_obs   = base_path,
            posmode    = posmode_val,
            elmask     = input$pos1_elmask,
            config_file = config_file
          )

          incProgress(0.8, detail = "Parsing output")

          if (result$exit_code == 0 && result$epochs > 0 && file.exists(result$output_file)) {
            df <- parse_rtkpos_output(result$output_file)
          }

          incProgress(1.0, detail = "Done")
        }
      )

      rv$result <- result
      rv$data <- df

      if (result$exit_code != 0) {
        rv$status <- "Error (see notification)"
        showNotification(
          paste("RTKPOS failed with exit code", result$exit_code),
          type = "error", duration = 10
        )
      } else if (is.null(df) || nrow(df) == 0) {
        rv$status <- "Done - 0 epochs (no output)"
        showNotification(
          "RTKPOS completed but no position data was produced.",
          type = "warning", duration = 10
        )
      } else {
        rv$status <- paste0("Done - ", nrow(df), " epochs")
        showNotification(
          paste("Processed", nrow(df), "epochs successfully."),
          type = "message", duration = 5
        )
      }

      # Print stderr to console for debugging
      if (!is.null(result$stderr) && nchar(result$stderr) > 0) {
        cat("=== rnx2rtkp stderr ===\n", result$stderr, "\n=======================\n")
      }
      # Also print stdout
      if (!is.null(result$stdout) && nchar(result$stdout) > 0) {
        cat("=== rnx2rtkp stdout ===\n", result$stdout, "\n=======================\n")
      }

    }, error = function(e) {
      rv$status <- "Error"
      showNotification(
        paste("Error:", e$message),
        type = "error", duration = 15
      )
    })
  })

  # =========================================================================
  # OUTPUT: Trajectory
  # =========================================================================
  output$trajectory_plot <- plotly::renderPlotly({
    req(rv$data, nrow(rv$data) > 0)
    p <- plot_trajectory(rv$data)
    plotly::ggplotly(p) |>
      plotly::layout(
        hoverlabel = list(bgcolor = "white", font = list(size = 10))
      )
  })

  # =========================================================================
  # OUTPUT: Height
  # =========================================================================
  output$height_plot <- plotly::renderPlotly({
    req(rv$data, nrow(rv$data) > 0)
    p <- plot_height(rv$data)
    plotly::ggplotly(p) |>
      plotly::layout(
        hoverlabel = list(bgcolor = "white", font = list(size = 10))
      )
  })

  # =========================================================================
  # OUTPUT: Data table
  # =========================================================================
  output$data_table <- DT::renderDT({
    req(rv$data, nrow(rv$data) > 0)
    df_show <- rv$data
    # Round numeric columns for display
    num_cols <- names(df_show)[sapply(df_show, is.numeric)]
    for (col in num_cols) {
      df_show[[col]] <- round(df_show[[col]], 4)
    }
    DT::datatable(
      df_show,
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        searching = TRUE,
        lengthMenu = c(10, 25, 50, 100)
      ),
      rownames = FALSE
    ) |>
      DT::formatStyle(columns = num_cols, `text-align` = "right")
  })

  # =========================================================================
  # OUTPUT: Summary
  # =========================================================================
  output$summary_table <- renderTable({
    req(rv$data, nrow(rv$data) > 0)
    df <- rv$data

    # Quality breakdown
    quality_counts <- table(factor(df$quality,
      levels = c("single", "dgps", "fixed", "float", "sbas", "other")))
    total <- nrow(df)

    # Position range
    lat_range <- range(df$lat, na.rm = TRUE)
    lon_range <- range(df$lon, na.rm = TRUE)
    hgt_range <- range(df$hgt, na.rm = TRUE)

    # Time span
    time_range <- range(df$time, na.rm = TRUE)

    data.frame(
      Metric = c(
        "Total Epochs",
        "Single",
        "DGPS",
        "Fixed (RTK)",
        "Float",
        "SBAS",
        "Other",
        "Latitude Range",
        "Longitude Range",
        "Height Range",
        "Start Time",
        "End Time"
      ),
      Value = c(
        total,
        quality_counts["single"],
        quality_counts["dgps"],
        quality_counts["fixed"],
        quality_counts["float"],
        quality_counts["sbas"],
        quality_counts["other"],
        paste(round(lat_range[1], 6), "to", round(lat_range[2], 6)),
        paste(round(lon_range[1], 6), "to", round(lon_range[2], 6)),
        paste(round(hgt_range[1], 3), "to", round(hgt_range[2], 3), "m"),
        format(time_range[1], "%Y-%m-%d %H:%M:%S"),
        format(time_range[2], "%Y-%m-%d %H:%M:%S")
      ),
      stringsAsFactors = FALSE
    )
  }, na = "0")

  output$summary_command <- renderText({
    req(rv$result)
    rv$result$command
  })

  output$summary_stderr <- renderText({
    req(rv$result)
    txt <- ""
    if (!is.null(rv$result$stderr) && nchar(rv$result$stderr) > 0) {
      txt <- paste0(txt, "=== stderr ===\n", rv$result$stderr, "\n")
    }
    if (!is.null(rv$result$stdout) && nchar(rv$result$stdout) > 0) {
      txt <- paste0(txt, "=== stdout ===\n", rv$result$stdout, "\n")
    }
    if (nchar(txt) == 0) txt <- "(no output)"
    txt
  })
}
