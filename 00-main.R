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

sim_paths <- list(
  cachePath = "cache",
  inputPath = "inputs",
  modulePath = "modules",
  outputPath = "outputs"
)

do.call(setPaths, sim_paths)

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
    simInitAndSpades(
      times = list(start = 0, end = 1),
      params = list(fireSense_ELFs = list()),
      modules = list("fireSense_ELFs"),
      paths = sim_paths,
      cache = use_cache
    )
  })
}

ELF_polys <- sf::st_read(elfs_gpkg, quiet = TRUE)

if (FALSE) {
  ggplot2::ggplot() + ggplot2::geom_sf(data = ELF_polys)
}
