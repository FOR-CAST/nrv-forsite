library(sf)
library(terra)
library(reproducible)
library(SpaDES.core)

use_cache <- FALSE ## TODO: re-enable once it's working correctly

options(
  reproducible.cacheSaveFormat = "rds",
  reproducible.destinationPath = "inputs",
  reproducible.gdalwarp = TRUE, ## TODO: prepInputs doing it wrong???
  reproducible.inputPaths = NULL,
  reproducible.memoisePersist = FALSE,
  reproducible.objSize = FALSE, ## TODO: restore TRUE when 'error: bad binding access' fixed
  reproducible.quick = FALSE,
  reproducible.shapefileRead = "terra::vect",
  reproducible.showSimilar = FALSE,
  reproducible.useCache = use_cache,
  reproducible.useCacheV3 = use_cache,
  reproducible.useCloud = FALSE, ## TODO: cloudCache spams Google Drive; doesn't respect drive path
  spades.allowInitDuringSimInit = FALSE, ## TODO: use TRUE when fixed / working correctly
  spades.allowSequentialCaching = FALSE,
  spades.memoryUseInterval = FALSE, ## TODO: broken with recent SpaDES.core versions; hangs indefinitely
  spades.messagingNumCharsModule = 36,
  spades.moduleCodeChecks = TRUE,
  spades.recoveryMode = FALSE,
  spades.useRequire = FALSE ## don't use Require; all pkgs installed via renv
)

terra::terraOptions(memfrac = 0) ## keep rasters on disk

## only need to run once to produce the ELFs polygons;
##
## NOTE: fireSense_ELFs module errors with:
##     Error in `ELFs$rasWhole[[ELF]]`:
##     ! attempt to select less than one element in get1index
## WARN: versions of the module after the first commit contain nested versions (#1)
## WORKAROUND: module produces ELF rasters, then manually creates polygons, saves and exits early.
elfs_gpkg <- file.path("inputs", "ELFs_final", "fireSense_ELFs.gpkg")
if (!file.exists(elfs_gpkg)) {
  local({
    sim_paths <- list(
      cachePath = "cache",
      inputPath = "inputs",
      modulePath = "modules",
      outputPath = "outputs"
    )

    do.call(setPaths, sim_paths)

    simInitAndSpades(
      times = list(start = 0, end = 1),
      params = list(fireSense_ELFs = list()),
      modules = list("fireSense_ELFs"),
      paths = sim_paths,
      cache = use_cache
    ) ## ~30 GB RAM
  })
}

ELF_polys <- sf::st_read(elfs_gpkg, quiet = TRUE)

if (FALSE) {
  ggplot2::ggplot() +
    ggplot2::geom_sf(data = ELF_polys) +
    ggplot2::geom_sf(
      data = dplyr::filter(ELF_polys, ELF_ID %in% c("6.2.1", "6.2.2", "6.2.3")),
      fill = c("darkred", "darkblue", "black"),
      alpha = 0.3
    )
}

## setup post-processing --------------------------------------------------------------------------

cs <- "" ## TODO: what is the climate scenario called?
elf_ids <- c("6.2.2") # ELF_polys$ELF_ID ## TODO: identify which ELFs were actually run

REPS <- 1L:5L ## TODO: adjust if more reps

posthoc_paths <- list(
  cachePath = "cache",
  inputPath = "inputs",
  modulePath = "modules",
  outputPath = "outputs"
)

do.call(setPaths, posthoc_paths)

parallel::mclapply(elf_ids, function(elf) {
  ## params
  posthoc_params <- list(
    NRV_summary = list(
      mode = "multi",
      postprocessEvents = "bc",
      sieveThresh = as.integer(1000 / 240) ## ~10 ha in pixels
    ),
    burnSummaries = list(
      mode = "multi" ## TODO: others?
    ),
    Biomass_summary = list(
      climateScenarios = cs,
      mode = "multi",
      reps = REPS,
      simOutputPath = dirname(posthoc_paths$outputPath), ## "outputs"
      studyAreaNames = elf,
      year = years
    ),
    fireSense_summary = list(
      climateScenarios = cs,
      simOutputPath = dirname(posthoc_paths$outputPath), ## "outputs"
      studyAreaNames = elf,
      reps = REPS,
      upload = doUpload
    )
  )

  ## objects
  sppEquiv <- TODO
  treeSpecies <- unique(sppEquiv[, c("LandR", "Type")])
  setnames(treeSpecies, "LandR", "Species")

  rasterToMatchReporting <- terra::rast(TODO)

  reportingPolygons <- list(
    elfs = ELF_polys ## TODO: others
  )

  ## TODO
  posthoc_objects <- list(
    rasterToMatch = rasterToMatchReporting,
    reportingPolygons = reportingPolygons,
    treeSpecies = treeSpecies ## Biomass_summary
  )

  posthocSim <- simInitAndSpades(
    times = list(start = 0, end = 1),
    params = posthoc_params,
    modules = posthoc_modules,
    loadOrder = unlist(posthoc_modules),
    objects = posthoc_objects,
    paths = sim_paths,
    cache = use_cache
  )

  # save simulation info ------------------------------------------------------------------------
  info_md <- file.path(posthoc_paths$outputPath, "INFO.md")
  cat(workflowtools::reproducibilityReceipt(), file = info_md, sep = "\n", append = TRUE)

  TRUE
})
