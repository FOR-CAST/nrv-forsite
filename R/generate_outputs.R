## produce dummy outputs for a set of ELFs

library(data.table)
library(sf)
library(terra)
# library(qs)
# library(qs2)

elfs_gpkg <- file.path("inputs", "ELFs_final", "fireSense_ELFs.gpkg")

ELF_polys <- sf::st_read(elfs_gpkg, quiet = TRUE)

ELF_ids <- c("14.1") ## entirely in BC; use WBI BC outputs

n_reps <- 5

if (FALSE) {
  elf = ELF_ids[1]
  rep_id = seq_len(n_reps)[1]
}

lapply(ELF_ids, function(elf) {
  studyArea <- dplyr::filter(ELF_polys, ELF_ID == elf) |> terra::vect()

  species <- qs::qread("wbi_outputs/BC_CanESM5_SSP370_run01/species_year2100.qs")
  sppEquiv <- LandR::sppEquivalencies_CA[LandR %in% species$species, ][
    !NFI %in% c("PINU_CON", "PINU_CON_CON"),
  ]
  sppColorVect <- c(setNames(sppEquiv$colorHex, sppEquiv$LandR), Mixed = "#895129")

  flammableMap <- LandR::defineFlammable(
    LandCoverClassifiedMap = terra::rast("wbi_inputs/LCC_BC.tif")
  ) |>
    terra::crop(studyArea)

  lapply(seq_len(n_reps), function(rep_id) {
    wbi_path <- file.path("wbi_outputs", sprintf("BC_CanESM5_SSP370_run%02d", rep_id))

    output_path <- file.path("outputs", "dummy", elf, sprintf("rep%02d", rep_id)) |>
      fs::dir_create()

    ## flammableMap -----------------------------------------------------------
    terra::writeRaster(
      flammableMap,
      file.path(output_path, "flammableMap_year_2100.tif"),
      overwrite = TRUE
    )

    ## burnMaps ---------------------------------------------------------------
    burnMaps <- fs::dir_ls(wbi_path, type = "file", regexp = "burnMap.*[.]tif$")

    purrr::walk(.x = burnMaps, .f = function(x) {
      terra::rast(x) |>
        terra::crop(studyArea) |>
        terra::writeRaster(filename = file.path(output_path, basename(x)), overwrite = TRUE)
    })

    ## cohortData / pixelGroupMaps --------------------------------------------
    cohortDatas <- fs::dir_ls(wbi_path, type = "file", regexp = "cohortData")
    pixelGroupMaps <- fs::dir_ls(wbi_path, type = "file", regexp = "pixelGroupMap.*[.]tif$")

    stopifnot(length(cohortDatas) == length(pixelGroupMaps))

    purrr::walk2(.x = cohortDatas, .y = pixelGroupMaps, .f = function(x, y) {
      yr <- stringr::str_extract(x, "(?<=cohortData_).*(?=_)")
      stopifnot(yr == stringr::str_extract(y, "(?<=pixelGroupMap_).*(?=_)"))

      cd <- qs::qread(x)

      pgm <- terra::rast(y) |>
        terra::crop(studyArea) |>
        terra::writeRaster(
          filename = file.path(output_path, paste0("pixelGroupMap_year", yr, ".tif")),
          overwrite = TRUE
        )
      pg_vals <- terra::values(pgm, mat = FALSE)

      cd2 <- cd[pixelGroup %in% pg_vals, ]
      qs2::qs_save(cd2, file.path(output_path, paste0("cohortData_year", yr, ".qs2")))

      ## make vegTypeMap and standAgeMap from cd2 / pgm
      vtm <- LandR::vegTypeMapGenerator(
        cd2,
        pgm,
        0.80,
        mixedType = 2,
        sppEquiv = sppEquiv,
        sppEquivCol = "LandR",
        colors = sppColorVect,
        doAssertion = getOption("LandR.assertions", TRUE)
      )
      vtm <- vtm |>
        terra::mask(studyArea) |>
        terra::writeRaster(
          filename = file.path(output_path, paste0("vegTypeMap_year", yr, ".tif")),
          overwrite = TRUE
        )

      sam <- LandR::standAgeMapGenerator(
        cd2,
        pgm,
        weight = "biomass",
        doAssertion = getOption("LandR.assertions", TRUE)
      ) |>
        terra::mask(studyArea) |>
        terra::writeRaster(
          filename = file.path(output_path, paste0("standAgeMap_year", yr, ".tif")),
          overwrite = TRUE
        )
    })
  })
})
