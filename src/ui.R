# =============================================================================
# ui.R - Shiny UI for RTKPOS Post-Processing
# =============================================================================

ui <- navbarPage(
  title = "RTKPOS Control",
  id = "main_nav",

  # ===========================================================================
  # TAB 1: Setup
  # ===========================================================================
  tabPanel(
    "Setup",
    fluidRow(

      # --- File inputs + Run button ---
      column(
        width = 12,
        wellPanel(
          fluidRow(
            column(
              width = 5,
              fileInput("rover_file", "Rover Observation (.obs / .YYo)",
                accept = c(".obs", ".OBS", ".rnx", ".RNX", ".o", ".O",
                          ".20o", ".21o", ".22o", ".23o", ".24o"),
                placeholder = "e.g. tmg23590.20o"
              ),
              fileInput("nav_file", "Navigation File (.nav / .n / .YYn)",
                accept = c(".nav", ".NAV", ".n", ".N", ".eph",
                          ".20n", ".21n", ".22n", ".23n", ".24n"),
                placeholder = "e.g. brdc.nav"
              ),
              fileInput("base_file", "Base Station OBS (optional)",
                accept = c(".obs", ".OBS", ".o", ".O", ".rnx", ".RNX",
                          ".20o", ".21o", ".22o", ".23o", ".24o"),
                placeholder = "e.g. tmg23590.20o"
              )
            ),
            column(
              width = 3, offset = 1,
              br(), br(),
              actionButton("run_btn", "Run RTKPOS",
                icon = icon("play"),
                class = "btn-primary btn-lg",
                width = "100%"
              ),
              br(), br(),
              verbatimTextOutput("run_status")
            )
          )
        )
      )
    ),

    # --- Accordion panels with parameters ---
    bslib::accordion(
      id = "param_accordion",
      open = FALSE,

      # Panel 1: Positioning Settings
      bslib::accordion_panel(
        "Positioning Settings",
        icon = shiny::icon("satellite"),
        fluidRow(
          column(width = 4,
            selectInput("pos1_posmode", "Positioning Mode",
              choices = c("single", "dgps", "kinematic", "static"),
              selected = "single"),
            selectInput("pos1_frequency", "Frequency",
              choices = c("l1", "l1+l2", "l1+l2+l5"),
              selected = "l1"),
            selectInput("pos1_soltype", "Solution Type",
              choices = c("forward", "backward", "combined"),
              selected = "forward"),
            numericInput("pos1_elmask", "Elevation Mask (deg)",
              value = 15, min = 0, max = 90, step = 1),
            selectInput("pos1_snrmask", "SNR Mask",
              choices = c("off", "on"), selected = "off")
          ),
          column(width = 4,
            selectInput("pos1_dynamics", "Dynamics",
              choices = c("off", "on"), selected = "off"),
            selectInput("pos1_tidecorr", "Tide Correction",
              choices = c("off", "on"), selected = "off"),
            selectInput("pos1_ionoopt", "Ionospheric Correction",
              choices = c("off", "brdc", "sbas", "dual-freq", "est-stec"),
              selected = "brdc"),
            selectInput("pos1_tropopt", "Tropospheric Correction",
              choices = c("off", "saas", "sbas", "est-ztd", "est-ztdgrad"),
              selected = "saas"),
            selectInput("pos1_sateph", "Satellite Ephemeris",
              choices = c("brdc", "precise", "brdc+sbas"),
              selected = "brdc")
          ),
          column(width = 4,
            checkboxGroupInput("pos1_navsys", "Navigation Systems",
              choices = c("GPS" = "1", "SBAS" = "2", "GLO" = "4",
                          "GAL" = "8", "QZSS" = "16", "BDS" = "32"),
              selected = "1"),
            textInput("pos1_exclsats", "Excluded Satellites",
              value = "", placeholder = "e.g. G01 G02")
          )
        )
      ),

      # Panel 2: Ambiguity Resolution
      bslib::accordion_panel(
        "Ambiguity Resolution",
        icon = shiny::icon("dot-circle"),
        fluidRow(
          column(width = 4,
            selectInput("pos2_armode", "AR Mode",
              choices = c("off", "continuous", "instantaneous", "fix-and-hold"),
              selected = "off"),
            selectInput("pos2_gloarmode", "GLONASS AR Mode",
              choices = c("off", "on", "autocal"),
              selected = "off"),
            numericInput("pos2_arthres", "AR Threshold",
              value = 3, min = 0, max = 3, step = 0.1)
          ),
          column(width = 4,
            numericInput("pos2_arlockcnt", "Lock Count for AR",
              value = 0, min = 0, step = 1),
            numericInput("pos2_arelmask", "Elevation Mask for AR (deg)",
              value = 0, min = 0, max = 90, step = 1),
            numericInput("pos2_arminfix", "Minimum Fix Count",
              value = 0, min = 0, step = 1)
          ),
          column(width = 4,
            numericInput("pos2_aroutcnt", "AR Output Counter",
              value = 0, min = 0, step = 1),
            numericInput("pos2_maxage", "Max Age of Differential Data (s)",
              value = 30, min = 0, step = 1)
          )
        )
      ),

      # Panel 3: Output Format
      bslib::accordion_panel(
        "Output Format",
        icon = shiny::icon("table"),
        fluidRow(
          column(width = 4,
            selectInput("out_solformat", "Solution Format",
              choices = c("llh", "xyz", "enu", "nmea"),
              selected = "llh"),
            selectInput("out_outhead", "Output Header",
              choices = c("on", "off"), selected = "on"),
            selectInput("out_outopt", "Output Options",
              choices = c("on", "off"), selected = "on"),
            selectInput("out_timesys", "Time System",
              choices = c("gpst", "utc", "jst"), selected = "gpst")
          ),
          column(width = 4,
            selectInput("out_timeform", "Time Format",
              choices = c("tow", "hms"), selected = "hms"),
            numericInput("out_timendec", "Time Decimals",
              value = 3, min = 0, max = 6, step = 1),
            selectInput("out_degform", "Degree Format",
              choices = c("deg", "dms"), selected = "deg")
          ),
          column(width = 4,
            textInput("out_fieldsep", "Field Separator",
              value = " ", placeholder = "space"),
            selectInput("out_height", "Height",
              choices = c("ellipsoidal", "geodetic"),
              selected = "ellipsoidal"),
            selectInput("out_solstatic", "Static Solution",
              choices = c("all", "single"), selected = "all")
          )
        )
      ),

      # Panel 4: Statistics & Filtering
      bslib::accordion_panel(
        "Statistics & Filtering",
        icon = shiny::icon("chart-line"),
        fluidRow(
          column(width = 4,
            numericInput("stats_errratio", "Code/Carrier Error Ratio",
              value = 100, min = 1, step = 1),
            numericInput("stats_errphase", "Carrier Phase Error Std (m)",
              value = 0.003, min = 0.001, step = 0.001),
            numericInput("stats_errphaseel", "Phase Error Std Elev-Dep (m)",
              value = 0.003, min = 0.001, step = 0.001)
          ),
          column(width = 4,
            numericInput("stats_errdoppler", "Doppler Error Std (Hz)",
              value = 1, min = 0.01, step = 0.1),
            numericInput("stats_stdbias", "Code Bias Std (m)",
              value = 30, min = 0.1, step = 1),
            numericInput("stats_stdiono", "Ionospheric Std (m)",
              value = 0.03, min = 0.001, step = 0.001)
          ),
          column(width = 4,
            numericInput("stats_stdtrop", "Tropospheric Std (m)",
              value = 0.3, min = 0.001, step = 0.1),
            numericInput("stats_prnaccelh", "Process Noise Accel Horiz (m/s^2)",
              value = 1, min = 0.001, step = 0.1),
            numericInput("stats_prnaccelv", "Process Noise Accel Vert (m/s^2)",
              value = 0.1, min = 0.001, step = 0.1)
          )
        )
      ),

      # Panel 5: Antenna Settings
      bslib::accordion_panel(
        "Antenna Settings",
        icon = shiny::icon("broadcast-tower"),
        h5("Rover (Antenna 1)"),
        fluidRow(
          column(width = 4,
            selectInput("ant1_postype", "Position Type",
              choices = c("llh", "single", "pos", "cartesian"),
              selected = "llh"),
            numericInput("ant1_pos1", "Pos 1 (lat / X)",
              value = 0, step = 0.0001)
          ),
          column(width = 4,
            numericInput("ant1_pos2", "Pos 2 (lon / Y)",
              value = 0, step = 0.0001),
            numericInput("ant1_pos3", "Pos 3 (hgt / Z)",
              value = 0, step = 0.01)
          ),
          column(width = 4,
            numericInput("ant1_antdele", "Antenna Delta E (m)",
              value = 0, step = 0.001),
            numericInput("ant1_antdeln", "Antenna Delta N (m)",
              value = 0, step = 0.001),
            numericInput("ant1_antdelu", "Antenna Delta U (m)",
              value = 0, step = 0.001)
          )
        ),
        hr(),
        h5("Base Station (Antenna 2)"),
        fluidRow(
          column(width = 4,
            selectInput("ant2_postype", "Position Type",
              choices = c("llh", "single", "pos", "cartesian"),
              selected = "single"),
            numericInput("ant2_pos1", "Pos 1 (lat / X)",
              value = 0, step = 0.0001)
          ),
          column(width = 4,
            numericInput("ant2_pos2", "Pos 2 (lon / Y)",
              value = 0, step = 0.0001),
            numericInput("ant2_pos3", "Pos 3 (hgt / Z)",
              value = 0, step = 0.01)
          ),
          column(width = 4,
            numericInput("ant2_antdele", "Antenna Delta E (m)",
              value = 0, step = 0.001),
            numericInput("ant2_antdeln", "Antenna Delta N (m)",
              value = 0, step = 0.001),
            numericInput("ant2_antdelu", "Antenna Delta U (m)",
              value = 0, step = 0.001)
          )
        )
      )
    )
  ),

  # ===========================================================================
  # TAB 2: Trajectory
  # ===========================================================================
  tabPanel(
    "Trajectory",
    br(),
    conditionalPanel(
      condition = "output.has_data == false",
      h4("No data yet. Run RTKPOS from Setup tab.", class = "text-muted text-center")
    ),
    conditionalPanel(
      condition = "output.has_data == true",
      plotly::plotlyOutput("trajectory_plot", height = "600px")
    )
  ),

  # ===========================================================================
  # TAB 3: Height
  # ===========================================================================
  tabPanel(
    "Height",
    br(),
    conditionalPanel(
      condition = "output.has_data == false",
      h4("No data yet. Run RTKPOS from Setup tab.", class = "text-muted text-center")
    ),
    conditionalPanel(
      condition = "output.has_data == true",
      plotly::plotlyOutput("height_plot", height = "600px")
    )
  ),

  # ===========================================================================
  # TAB 4: Data
  # ===========================================================================
  tabPanel(
    "Data",
    br(),
    conditionalPanel(
      condition = "output.has_data == false",
      h4("No data yet. Run RTKPOS from Setup tab.", class = "text-muted text-center")
    ),
    conditionalPanel(
      condition = "output.has_data == true",
      DT::DTOutput("data_table")
    )
  ),

  # ===========================================================================
  # TAB 5: Summary
  # ===========================================================================
  tabPanel(
    "Summary",
    br(),
    conditionalPanel(
      condition = "output.has_data == false",
      h4("No data yet. Run RTKPOS from Setup tab.", class = "text-muted text-center")
    ),
    conditionalPanel(
      condition = "output.has_data == true",
      wellPanel(
        h4("Processing Summary"),
        tableOutput("summary_table")
      ),
      wellPanel(
        h4("Command"),
        verbatimTextOutput("summary_command")
      ),
      wellPanel(
        h4("rnx2rtkp Output (stdout/stderr)"),
        verbatimTextOutput("summary_stderr")
      )
    )
  )
)
