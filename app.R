# =============================================================================
# app.R - Shiny App for RTKPOS Post-Processing
# =============================================================================
# Usage: run from project root directory:
#   shiny::runApp("app.R")
# =============================================================================

options(shiny.maxRequestSize = 100 * 1024 ^ 2)

source("src/rtkpos_backend.R")
source("src/ui.R")
source("src/server.R")

shinyApp(ui = ui, server = server)
