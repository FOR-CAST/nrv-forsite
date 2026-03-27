## indirect package dependencies to appease renv
if (FALSE) {
  library(archive)
  library(arrow)
  library(cluster)
  library(foreign)
  library(future.callr)
  library(httpuv) ## used by googledrive
  library(NLMR) ## used by SpaDES.tools / SpaDES.core
  library(rpart) ## used by ggplot2 and others
  library(spatstat.data)
  library(spatstat.geom)
  library(spatstat.random)
  library(spatstat.univar)
  library(spatstat.utils)
  library(spatial)
  library(zonal) ## used for producing summaries
}
