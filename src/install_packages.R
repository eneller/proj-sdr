# =============================================================================
# install_packages.R
# Install all R packages required for the RTKPOS backend
# =============================================================================
# Run this script once before using the backend or Shiny app.
# Usage: Rscript install_packages.R

required_packages <- c(
  "shiny",        # web GUI framework
  "shinythemes",  # Shiny UI themes
  "bslib",        # Bootstrap theming
  "ggplot2",      # plotting
  "DT",           # interactive tables
  "plotly",       # interactive plots (optional)
  "processx"      # better system call handling (optional)
)

installed <- rownames(installed.packages())
to_install <- setdiff(required_packages, installed)

if (length(to_install) > 0) {
  cat("Installing missing packages:\n")
  cat("  ", paste(to_install, collapse = "\n  "), "\n")
  install.packages(to_install, repos = "https://cloud.r-project.org")
  cat("\nDone.\n")
} else {
  cat("All required packages are already installed.\n")
}

cat("\nPackage status:\n")
for (pkg in required_packages) {
  status <- ifelse(pkg %in% installed, "OK", "MISSING")
  cat("  [", status, "]", pkg, "\n")
}
