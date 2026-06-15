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
    list(
      "pos1-posmode"    = input$pos1_posmode,
      "pos1-frequency"  = input$pos1_frequency,
      "pos1-soltype"    = input$pos1_soltype,
      "pos1-elmask"     = as.character(input$pos1_elmask),
      "pos1-snrmask"    = input$pos1_snrmask,
      "pos1-dynamics"   = input$pos1_dynamics,
      "pos1-tidecorr"   = input$pos1_tidecorr,
      "pos1-ionoopt"    = input$pos1_ionoopt,
      "pos1-tropopt"    = input$pos1_tropopt,
      "pos1-sateph"     = input$pos1_sateph,
      "pos1-navsys"     = as.character(sum(as.integer(input$pos1_navsys))),
      "pos1-exclsats"   = input$pos1_exclsats,
      "pos2-armode"     = input$pos2_armode,
      "pos2-gloarmode"  = input$pos2_gloarmode,
      "pos2-arthres"    = as.character(input$pos2_arthres),
      "pos2-arlockcnt"  = as.character(input$pos2_arlockcnt),
      "pos2-arelmask"   = as.character(input$pos2_arelmask),
      "pos2-arminfix"   = as.character(input$pos2_arminfix),
      "pos2-aroutcnt"   = as.character(input$pos2_aroutcnt),
      "pos2-maxage"     = as.character(input$pos2_maxage),
      "out-solformat"   = input$out_solformat,
      "out-outhead"     = input$out_outhead,
      "out-outopt"      = input$out_outopt,
      "out-timesys"     = input$out_timesys,
      "out-timeform"    = input$out_timeform,
      "out-timendec"    = as.character(input$out_timendec),
      "out-degform"     = input$out_degform,
      "out-fieldsep"    = if (nchar(input$out_fieldsep) == 0) " " else input$out_fieldsep,
      "out-height"      = input$out_height,
      "out-solstatic"   = input$out_solstatic,
      "stats-errratio"  = as.character(input$stats_errratio),
      "stats-errphase"  = as.character(input$stats_errphase),
      "stats-errphaseel" = as.character(input$stats_errphaseel),
      "stats-errdoppler" = as.character(input$stats_errdoppler),
      "stats-stdbias"   = as.character(input$stats_stdbias),
      "stats-stdiono"   = as.character(input$stats_stdiono),
      "stats-stdtrop"   = as.character(input$stats_stdtrop),
      "stats-prnaccelh" = as.character(input$stats_prnaccelh),
      "stats-prnaccelv" = as.character(input$stats_prnaccelv),
      "ant1-postype"    = input$ant1_postype,
      "ant1-pos1"       = as.character(input$ant1_pos1),
      "ant1-pos2"       = as.character(input$ant1_pos2),
      "ant1-pos3"       = as.character(input$ant1_pos3),
      "ant1-antdele"    = as.character(input$ant1_antdele),
      "ant1-antdeln"    = as.character(input$ant1_antdeln),
      "ant1-antdelu"    = as.character(input$ant1_antdelu),
      "ant2-postype"    = input$ant2_postype,
      "ant2-pos1"       = as.character(input$ant2_pos1),
      "ant2-pos2"       = as.character(input$ant2_pos2),
      "ant2-pos3"       = as.character(input$ant2_pos3),
      "ant2-antdele"    = as.character(input$ant2_antdele),
      "ant2-antdeln"    = as.character(input$ant2_antdeln),
      "ant2-antdelu"    = as.character(input$ant2_antdelu)
    )
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

          base_path <- if (has_base) input$base_file$datapath else NULL

          result <- run_rtkpos(
            rover_obs  = input$rover_file$datapath,
            nav_file   = input$nav_file$datapath,
            base_obs   = base_path,
            posmode    = posmode_val,
            elmask     = input$pos1_elmask,
            config_file = config_file
          )

          incProgress(0.8, detail = "Parsing output")

          if (result$exit_code == 0 && file.exists(result$output_file)) {
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
    plotly::ggplotly(p) %>%
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
    plotly::ggplotly(p) %>%
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
    ) %>%
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
}
