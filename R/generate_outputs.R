elfs_gpkg <- file.path("inputs", "ELFs_final", "fireSense_ELFs.gpkg")

ELF_polys <- sf::st_read(elfs_gpkg, quiet = TRUE)

ELF_ids <- c("6.2.2")

lapply(ELF_ids, function(elf) {
  ##
})
