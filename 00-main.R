# workflowtools::check_project_packages()

library(data.table)
library(sf)
library(terra)
library(reproducible)
library(SpaDES.core)

fig_path <- file.path("outputs", "figures") |> fs::dir_create()
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
  can_provs <- geodata::gadm("CA") |> sf::st_as_sf()

  gg_elfs <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = ELF_polys) +
    ggplot2::geom_sf(data = can_provs, col = "black", fill = NA) +
    ggplot2::geom_sf_label(data = ELF_polys, ggplot2::aes(label = ELF_ID), size = 3) +
    ggplot2::geom_sf(
      data = dplyr::filter(ELF_polys, ELF_ID %in% c("14.1", "6.1.1", "6.2.2")),
      fill = c("darkred", "darkblue", "orange"),
      alpha = 0.3
    ) +
    ggplot2::labs(title = "ELF polygon map", x = "Longitude", y = "Latitude")

  ggplot2::ggsave(
    filename = file.path(fig_path, "map_elfs.png"),
    plot = gg_elfs,
    width = 12,
    height = 12
  )
}

## setup post-processing --------------------------------------------------------------------------

study_areas <- c("4.3") # ELF_polys$ELF_ID ## TODO: identify which ELFs were actually run
rv_periods <- c("1991-2020") ## TODO
climate_scenarios <- c("CNRM-ESM2-1_ssp370") ## TODO: should be "NRV"

REPS <- 1L # 1L:5L ## TODO: adjust if more reps

if (FALSE) {
  ## use for testing the loops
  sa = study_areas[1]
  rv = rv_periods[1]
  cs = climate_scenarios[1]
}

lapply(study_areas, function(sa) {
  lapply(scenarios, function(scenario) {
    lapply(climate_scenarios, function(cs) {
      ##
      posthoc_paths <- list(
        cachePath = "cache",
        inputPath = "inputs",
        modulePath = "modules",
        outputPath = file.path("outputs", "testing", sa, scenario, cs) ## TODO: use real outputs once they are available
      )

      do.call(setPaths, posthoc_paths)

      ## params
      posthoc_params <- list(
        burnSummaries = list(
          mode = "multi", ## TODO: others?
          reps = REPS,
          simOutputPath = posthoc_paths$outputPath,
          simTimes = c(2011L, 2100L),
          summaryInterval = 50L,
          summaryPeriod = c(2720L, 2320L) ## TODO: confirm
        ),
        NRV_summary = list(
          mode = "multi",
          postprocessEvents = c("lm", "pm"),
          reps = REPS,
          sieveThresh = as.integer(1000 / 240), ## ~10 ha in pixels
          simOutputPath = posthoc_paths$outputPath,
          simTimes = c(2011L, 2100L),
          summaryInterval = 50L,
          summaryPeriod = c(2720L, 2320L) ## TODO: confirm
        ),
        Biomass_summary = list(
          climateScenario = cs,
          mode = "multi",
          reps = REPS,
          simOutputPath = posthoc_paths$outputPath,
          studyAreaNames = sa,
          years = c(2020L, 3020L)
        ),
        # TODO: ensure fireSense_summary is run in single mode to output necessary files
        fireSense_summary = list(
          climateScenario = cs,
          mode = "multi",
          reps = REPS,
          simOutputPath = posthoc_paths$outputPath,
          studyAreaNames = sa,
          years = c(2020, 3020L)
        )
      )

      posthoc_modules <- names(posthoc_params)

      ## objects
      sppEquiv <- qs2::qs_read(file.path(
        posthoc_paths$outputPath,
        "rep01",
        "sppEquiv_year2020.qs2"
      )) ## same for all reps

      sppColorVect <- qs2::qs_read(file.path(
        posthoc_paths$outputPath,
        "rep01",
        "sppColorVect_year2020.qs2"
      )) ## same for all reps

      treeSpecies <- unique(sppEquiv[, c("LandR", "Type")])
      setnames(treeSpecies, "LandR", "Species")

      rasterToMatch <- terra::rast(file.path(
        posthoc_paths$outputPath,
        "rep01/pixelGroupMap_year2020.tif"
      ))
      rasterToMatch[!is.na(rasterToMatch[])] <- 0L ## need to have values, but keep NAs

      studyAreaReporting <- dplyr::filter(ELF_polys, ELF_ID == sa) |>
        terra::vect() |>
        terra::project(rasterToMatch)

      ## TODO: add other reporting polygons
      reportingPolygons <- list(
        elfs = dplyr::mutate(ELF_polys, ID = ELF_ID, NAME = ELF_ID, .before = "ELF_ID")
      ) |>
        lapply(sf::st_transform, crs = sf::st_crs(studyAreaReporting))

      ## TODO
      posthoc_objects <- list(
        rasterToMatch = rasterToMatch,
        rasterToMatchReporting = rasterToMatch,
        reportingPolygons = reportingPolygons,
        studyAreaReporting = studyAreaReporting,
        treeSpecies = treeSpecies ## Biomass_summary
      )

      posthocSim <- simInitAndSpades(
        times = list(start = 0, end = 1),
        params = posthoc_params,
        modules = posthoc_modules,
        loadOrder = unlist(posthoc_modules),
        objects = posthoc_objects,
        paths = posthoc_paths,
        cache = use_cache
      )

      # save simulation info ------------------------------------------------------------------------
      info_md <- file.path(posthoc_paths$outputPath, "INFO.md")
      cat(workflowtools::reproducibilityReceipt(), file = info_md, sep = "\n", append = TRUE)

      TRUE
    })
  })
})
