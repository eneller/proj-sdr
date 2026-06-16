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

    # --- Parameter groups (wellPanel) ---

    wellPanel(
      h4(icon("satellite"), "Positioning Settings"),
      fluidRow(
        column(width = 4,
          selectInput("pos1_posmode", "Positioning Mode",
            choices = c("single", "dgps", "kinematic", "static"),
            selected = "single"),
          numericInput("pos1_elmask", "Elevation Mask (deg)",
            value = 15, min = 0, max = 90, step = 1)
        ),
        column(width = 6,
          checkboxGroupInput("pos1_navsys", "Navigation Systems",
            choices = c("GPS" = "1", "SBAS" = "2", "GLO" = "4",
                        "GAL" = "8", "QZSS" = "16", "BDS" = "32"),
            selected = "1", inline = TRUE)
        )
      )
    ),

    wellPanel(
      h4(icon("dot-circle"), "Ambiguity Resolution"),
      selectInput("pos2_armode", "AR Mode",
        choices = c("off", "continuous", "instantaneous", "fix-and-hold"),
        selected = "off")
    ),

    wellPanel(
      h4(icon("table"), "Output Format"),
      fluidRow(
        column(width = 4,
          selectInput("out_solformat", "Solution Format",
            choices = c("llh", "xyz", "enu", "nmea"),
            selected = "llh"),
          selectInput("out_timesys", "Time System",
            choices = c("gpst", "utc", "jst"), selected = "gpst")
        ),
        column(width = 4,
          selectInput("out_height", "Height",
            choices = c("ellipsoidal", "geodetic"),
            selected = "ellipsoidal")
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
