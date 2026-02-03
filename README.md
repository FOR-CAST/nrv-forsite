# nrv-forsite

| Indicator                                | Module/Package             |
| :--------------------------------------- | :------------------------- |
| Age class distributions by tree species  | `NRV_summary` / `nrvtools` |
| Age class distributions by site (all tree species)  | `NRV_summary` / `nrvtools` |
| Age class distributions by type (conifer, deciduous, mixed) | `NRV_summary` / `nrvtools` |
| Land cover distributions by forest types (conifer, deciduous, mixed); | `NRV_summary` / `nrvtools` |
| Tree biomass by species                  | `NRV_summary` / `nrvtools` |
| Patch size distributions                 | `NRV_summary` / `nrvtools` |
| Fire regimes and fire sizes              | `burnSummaries` |

## Getting started

### Project setup

**R version 4.4.3**

```r
renv::restore()
```

### Running simulations

Be sure to include these modules, and specify the parameter `mode = "single"` when setting up runs, and specify the replicate ID.

### Post-processing summaries

After having run several replicates, results can be summarized using `mode = "multi"` and passing the replicate information to each module.
