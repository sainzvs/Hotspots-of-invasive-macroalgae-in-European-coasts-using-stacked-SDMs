rm(list=ls())


packages <- c("openxlsx", "dplyr", "biooracler", "rerddap", "ncdf4", "emodnet.wfs", "sf", "RANN")

for(p in packages){
  if(!requireNamespace(p, quietly = TRUE)){
    install.packages(p)
  }
}


library(openxlsx)
library(dplyr)
library(biooracler)
library(ncdf4)
library(emodnet.wfs)
library(sf)

setwd("D:/Proyectos/EMODNET_DP3")

variables <- biooracler::list_layers(simplify = T) # Check all layers
variables <- variables %>%
  filter(dataset_id %in% c("thetao_baseline_2000_2019_depthmean",
                           "no3_baseline_2000_2018_depthmean",
                           "ph_baseline_2000_2018_depthmean",
                           "po4_baseline_2000_2018_depthmean",
                           "so_baseline_2000_2019_depthmean",
                           "swd_baseline_2000_2019_depthmean",
                           "sws_baseline_2000_2019_depthmean",
                           "terrain_characteristics"))

variables_proj <- variables %>%
  filter(dataset_id %in% c("thetao_ssp245_2020_2100_depthmean",
                           "thetao_ssp585_2020_2100_depthmean",
                           "no3_ssp245_2020_2100_depthmean",
                           "no3_ssp585_2020_2100_depthmean",
                           "ph_ssp245_2020_2100_depthmean",
                           "ph_ssp585_2020_2100_depthmean",
                           "po4_ssp245_2020_2100_depthmean",
                           "po4_ssp585_2020_2100_depthmean",
                           "so_ssp245_2020_2100_depthmean",
                           "so_ssp585_2020_2100_depthmean",
                           "swd_ssp245_2020_2100_depthmean",
                           "swd_ssp585_2020_2100_depthmean",
                           "sws_ssp245_2020_2100_depthmean",
                           "sws_ssp585_2020_2100_depthmean"))

info_layer("thetao_ssp245_2020_2100_depthmean")

time1 = c("1970-01-01T00:00:00Z", "1970-01-01T00:00:00Z")
time = c('2010-01-01T00:00:00Z', '2010-01-01T00:00:00Z')
latitude = c(-89.975, 89.975)
longitude = c(-179.975, 179.975)

# Present-day conditions
i=8
for (i in 1:length(variables$dataset_id)) {
  if(variables$dataset_id[i] %in% c("terrain_characteristics")) {
    prev <- dir("./EV/raw", full.names = TRUE, pattern = ".nc")
    
    constraints = list(time1, latitude, longitude)
    names(constraints) = c("time", "latitude", "longitude")
    download_layers(dataset_id = variables$dataset_id[i],
                    variables = NULL,
                    fmt = "nc",
                    constraints = constraints,
                    directory = "./EV/raw")
    post <- dir("./EV/raw", full.names = TRUE, pattern = ".nc")
    new  <- setdiff(post, prev)
    
    
    if (length(new) == 0) {
      warning("Not new files")
      next
    }
    
    file.rename(new, paste0("./EV/raw/", variables$dataset_id[i], ".nc"))
    
    rm(i,prev,post,new,constraints)
    
    
    
  } else {
    prev <- dir("./EV/raw", full.names = TRUE, pattern = ".nc")
    
    constraints = list(time, latitude, longitude)
    names(constraints) = c("time", "latitude", "longitude")
    download_layers(dataset_id = variables$dataset_id[i],
                    variables = NULL,
                    fmt = "nc",
                    constraints = constraints,
                    directory = "./EV/raw")
    
    post <- dir("./EV/raw", full.names = TRUE, pattern = ".nc")
    new  <- setdiff(post, prev)
    
    
    if (length(new) == 0) {
      warning("Not new files")
      next
    }
    
    file.rename(new, paste0("./EV/raw/", variables$dataset_id[i], ".nc"))
    rm(i,prev,post,new,constraints)
  }
}

rm(longitude, latitude, time, time1, variables)

# Projected variables
time <- list(c('2040-01-01T00:00:00Z', '2040-01-01T00:00:00Z'), c('2090-01-01T00:00:00Z', '2090-01-01T00:00:00Z'))
latitude_sets <- list(c(0,89.975), c(0,89.975), c(-89.975,0), c(-89.975,0))
longitude_sets <- list(c(0,179.975), c(-179.975,0), c(-179.975,0), c(0, 179.975))

for (i in 1:length(variables_proj$dataset_id)) {
  
  for (j in 1:length(time)) {
    
    for (k in 1:length(longitude_sets)) {
    
    prev <- dir("./EV/proj_raw", full.names = TRUE, pattern = ".nc")
    
    constraints = list(time[[j]], latitude_sets[[k]], longitude_sets[[k]])
    names(constraints) = c("time", "latitude", "longitude")
    download_layers(dataset_id = variables_proj$dataset_id[i],
                    variables = NULL,
                    fmt = "nc",
                    constraints = constraints,
                    directory = "./EV/proj_raw")
    
    post <- dir("./EV/proj_raw", full.names = TRUE, pattern = ".nc")
    new  <- setdiff(post, prev)
    
    
    if (length(new) == 0) {
      warning("Not new files")
      next
    }
    
    file.rename(new, paste0("./EV/proj_raw/", variables_proj$dataset_id[i], "_", substr(time[[j]][1], 1,4), "_", k, ".nc"))
    rm(prev,post,new,constraints)
    
    }
  }
}

rm(longitude_sets, latitude_sets, time, time1, variables_proj, i,j,k)

# PAR and KD_PAR variables: Cannot be downloaded in a single download from ERDDAP (Need to split download in 4 parts)

PAR_variables <- c("kdpar_mean_baseline_2000_2020_depthsurf",
                   "par_mean_baseline_2000_2020_depthsurf")

latitude_sets <- list(c(0,89.975), c(0,89.975), c(-89.975,0), c(-89.975,0))
longitude_sets <- list(c(0,179.975), c(-179.975,0), c(-179.975,0), c(0, 179.975))

for (i in 1: length(PAR_variables)) {
  
  for (j in 1:length(longitude_sets)) {
    prev <- dir("./EV/raw/par", full.names = TRUE, pattern = ".nc")
    
    rerddap::griddap(PAR_variables[i],
                     url="http://erddap.bio-oracle.org/erddap/",
                     time = c('2010-01-01T00:00:00Z', '2010-01-01T00:00:00Z'),
                     latitude = latitude_sets[[j]],
                     longitude = longitude_sets[[j]],
                     fmt="nc",
                     store=rerddap::disk(path="./EV/raw/par"),
                     callopts = list(connecttimeout = 60L,
                                     timeout = 3600L,
                                     verbose = FALSE))
    
    post <- dir("./EV/raw/par", full.names = TRUE, pattern = ".nc")
    new  <- setdiff(post, prev)
    
    
    if (length(new) == 0) {
      warning("Not new files")
      next
    }
    
    file.rename(new, paste0("./EV/raw/par/", PAR_variables[i], "_", j, ".nc"))
    
    rm(j,prev,post,new)
  }
}

rm(PAR_variables, longitude_sets, latitude_sets)



# From raw to depth filter (100m)

# Open bathymetry to create mesh
nc <- nc_open("./EV/raw/terrain_characteristics.nc")
# names(nc$var)
# print(nc)
lon <- ncvar_get(nc, "longitude")
lat <- ncvar_get(nc, "latitude")
bathy <- ncvar_get(nc, "bathymetry_mean")
df_depth <- expand.grid(lon = lon, lat = lat)
df_depth$depth <- as.vector(bathy)
# df <- na.omit(df)
df_depth <- df_depth %>%
  mutate(depth = ifelse(depth > -100 & depth <= 0, depth, NA))
# ggplot() + geom_raster(data=df_depth, aes(x=lon,y=lat,fill=depth))
nc_close(nc)
rm(nc,lon,lat,bathy)

# Raw to depth
datasets <- list.files("./EV/raw/", pattern=".nc")
# i=2
for (i in 1:length(datasets)) {
  nc <- nc_open(paste0("./EV/raw/", datasets[i]))
  lon <- ncvar_get(nc, "longitude")
  lat <- ncvar_get(nc, "latitude")
  df <- expand.grid(lon = lon, lat = lat)
  df <- left_join(df, df_depth)
  names(df)[3] <- "depth_ref"
  data <- lapply(nc$var, function(v) ncvar_get(nc, v))
  
  # v=names(nc$var)[1]
  for (v in names(nc$var)) {
    df[[v]] <- as.vector(data[[v]])
    df <- df %>%
      mutate(!!v := ifelse(is.na(depth_ref), NA, !!sym(v)))
    rm(v)
  }
  
  
  df <- df %>%
    filter(!if_all(-c(lon, lat), is.na))
  
  write.csv(df, 
            paste0("./EV/depth_limited/", 
                       tools::file_path_sans_ext(datasets[i]),
                       ".csv"), 
            row.names = FALSE)
  
  nc_close(nc)
  rm(nc,data,df,lat,lon,i)
  
}

rm(datasets)

# For KD and PAR
datasets <- list.files("./EV/raw/par")
patterns <- c("^kdpar", "^par")

i=1
for (i in 1:length(patterns)) {
  
  sets <- datasets[stringr::str_detect(datasets, patterns[i])]
  
  nc <- nc_open(paste0("./EV/raw/par/", sets[1]))
  var_names <- names(nc$var)
  df <- data.frame(matrix(ncol = length(var_names)+2, nrow = 0))
  names(df) <- c("lon", "lat", names(nc$var))
  nc_close(nc)
  rm(nc)
  
  # j=1
  for (j in 1:length(sets)) {
    nc <- nc_open(paste0("./EV/raw/par/", sets[j]))
    lon <- ncvar_get(nc, "longitude")
    lat <- ncvar_get(nc, "latitude")
    df2 <- expand.grid(lon = lon, lat = lat)
    data <- lapply(nc$var, function(v) ncvar_get(nc, v))
    
    # v=names(nc$var)[1]
    for (v in names(nc$var)) {
      df2[[v]] <- as.vector(data[[v]])
      rm(v)
    }
    
    df <- rbind(df, df2)
    
    nc_close(nc)
    rm(nc,data,df2,lat,lon,j)
    
  }
  
  
  df <- df[!duplicated(df), ]
  write.csv(df, paste0("./EV/raw/", sub("_1.*$", "", sets[1]), ".csv"), row.names=F)
  
  df <- left_join(df, df_depth)
  
  for (v in var_names) {
    df <- df %>%
      mutate(!!v := ifelse(is.na(depth), NA, !!sym(v)))
    rm(v)
  }
  
  df <- df %>%
    filter(!if_all(-c(lon, lat), is.na))
  
  write.csv(df, 
            paste0("./EV/depth_limited/", sub("_1.*$", "", sets[1]),".csv"), 
            row.names = FALSE)
  
  rm(var_names, df, sets,i)
 
  
}

rm(datasets, patterns)

# Distance to ports (in meters)
services <- emodnet_wfs()
a <- emodnet_get_wfs_info(service = "seabed_habitats_general_datasets_and_products")
wfs <- emodnet_init_wfs_client(service = "human_activities")
rm(services)

emodnet <- emodnet_get_layers(
  wfs,
  layers = "portlocations",
  simplify = FALSE)
ports <- emodnet[[1]]
ports <- ports %>% st_transform(3857)
rm(emodnet)


grid <- read.csv(paste0("./EV/depth_limited/", "no3_baseline_2000_2018_depthmean.csv"))
grid <- grid %>% select(lon,lat) %>% 
  mutate(lon1 = lon, lat1 = lat) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4326) %>% 
  st_transform(3857) 


nn <- RANN::nn2(st_coordinates(ports), st_coordinates(grid), k = 1)
grid$dist_min <- nn$nn.dists[,1]
grid$port_id  <- nn$nn.idx[,1]

distances <- grid %>% select(lon1, lat1, dist_min) %>% st_drop_geometry()
names(distances) <- c("lon", "lat", "port_distance")
rm(grid, nn, ports,wfs)

write.csv(distances, "./EV/depth_limited/distances_to_ports.csv", row.names = F)
rm(distances)

# Projected variables
datasets <- list.files("./EV/proj_raw/")
names_base <- sub("_[1-4]\\.nc$", "", basename(datasets))
names <- unique(names_base)

i=1
for (i in 3:length(names)) {
  
  sets <- datasets[names_base == names[[i]]]
  
  nc <- nc_open(paste0("./EV/proj_raw/", sets[1]))
  var_names <- names(nc$var)
  df <- data.frame(matrix(ncol = length(var_names)+2, nrow = 0))
  names(df) <- c("lon", "lat", names(nc$var))
  nc_close(nc)
  rm(nc)
  
  # j=1
  for (j in 1:length(sets)) {
    nc <- nc_open(paste0("./EV/proj_raw/", sets[j]))
    lon <- ncvar_get(nc, "longitude")
    lat <- ncvar_get(nc, "latitude")
    df2 <- expand.grid(lon = lon, lat = lat)
    data <- lapply(nc$var, function(v) ncvar_get(nc, v))
    
    # v=names(nc$var)[1]
    for (v in names(nc$var)) {
      df2[[v]] <- as.vector(data[[v]])
      rm(v)
    }
    
    df <- rbind(df, df2)
    
    nc_close(nc)
    rm(nc,data,df2,lat,lon,j)
    
  }
  
  
  df <- df[!duplicated(df), ]
  # write.csv(df, paste0("./EV/raw/", sub("_1.*$", "", sets[1]), ".csv"), row.names=F)
  
  df <- left_join(df, df_depth)
  
  for (v in var_names) {
    df <- df %>%
      mutate(!!v := ifelse(is.na(depth), NA, !!sym(v)))
    rm(v)
  }
  
  df <- df %>%
    filter(!if_all(-c(lon, lat), is.na))
  
  write.csv(df, 
            paste0("./EV/proj_depth_limited/", sub("_1.*$", "", sets[1]),".csv"), 
            row.names = FALSE)
  
  rm(var_names, df, sets,i)
  
  
}

rm(df_depth, datasets, patterns, names, names_base, variables, variables_proj)


# SEABED Habitats
services <- emodnet_wfs()
wfs <- emodnet_init_wfs_client(service = "seabed_habitats_general_datasets_and_products")
layer_attributes_tbl(wfs, layer = "eusm2025_subs_full")
rm(services)

emodnet <- emodnet_get_layers(
  wfs,
  layers = "eusm2025_subs_full",
  simplify = FALSE,
  outputFormat = "CSV",
  path = "./")
seabed <- emodnet[[1]]
seabed_sf <- sf::st_as_sf(seabed, wkt = "geom", crs = 3857)
seabed <- seabed %>% st_transform(4326)
rm(emodnet)




