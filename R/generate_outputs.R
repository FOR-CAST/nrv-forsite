## produce dummy outputs for a set of ELFs

elfs_gpkg <- file.path("inputs", "ELFs_final", "fireSense_ELFs.gpkg")

ELF_polys <- sf::st_read(elfs_gpkg, quiet = TRUE)

ELF_ids <- c("6.2.2")

n_reps <- 5

if (FALSE) {
  elf = ELF_ids[1]
  rep_id = seq_len(n_reps)[1]
}

lapply(ELF_ids, function(elf) {
  lapply(seq_len(n_reps), function(rep_id) {
    output_path <- file.path("outputs", "dummy", elf, sprintf("rep%02d", rep_id)) |>
      fs::dir_create()

    studyArea <- dplyr::filter(ELF_polys, ELF_ID == elf)
  })
})
