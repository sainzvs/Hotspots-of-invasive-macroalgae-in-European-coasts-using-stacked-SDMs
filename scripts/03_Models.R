rm(list=ls())

packages <- c("sf", "biomod2", "ggplot2", "dplyr", "openxlsx", "spThin", "RANN", "usdm")

for(p in packages){
  if(!requireNamespace(p, quietly = TRUE)){
    install.packages(p)
  }
}

library(sf)
library(biomod2)
library(ggplot2)
library(dplyr)

setwd("D:/Proyectos/EMODNET_DP3")

# Load Presences
Species_List <- openxlsx::read.xlsx("./Listado/Listado_especies.xlsx", sheet = 3)
Data <- read.csv("./Ocurrencias/Ocurrencias.csv")
# Data <- Data[,-1]

# Spatial thinning (10km)
Data_thin <- data.frame("Species"=NA,"AphiaID"=NA, "lon"=NA, "lat"=NA)

i=1
for (i in 1:length(unique(Data$species))){
  
  subset <- Data %>% filter(species == unique(Data$species)[i])
  
  subset_thin <- spThin::thin(loc.data = subset, 
                            lat.col= "lat", long.col = "lon", spec.col = "species", 
                            thin.par = 10, reps = 1, 
                            locs.thinned.list.return = TRUE,
                            write.files = FALSE,
                            write.log.file = FALSE)
  subset_thin <- as.data.frame(subset_thin[[1]])
  subset_thin$Species <- unique(Data$species)[i]
  subset_thin$AphiaID <- subset$AphiaID[1]
  names(subset_thin)[c(1,2)] <- c("lon", "lat")
  subset_thin <- subset_thin[c(3,4,1,2)]
  
  
  Data_thin <- rbind(Data_thin, subset_thin)
  
  rm(subset, subset_thin, i)
}

Data_thin <- Data_thin[-1,]

rm(Data, Species_List)

# Load Environmental variables

variables <- c("port_distance", # Distance to closest port
               "kdpar_mean_mean","par_mean_mean",  #"bathymetry_mean", # Light related variables
               "no3_mean", "po4_mean", # Nutrients
               "so_mean", "ph_mean", # Water chemistry
               "thetao_mean", # Temperature
               "sws_mean", "swd_mean") # Water motion and storminess
               # "slope", "terrain_ruggedness_index") # Terrain (seabottom) characteristics

dataset_list <- list.files("./EV/depth_limited", full.names = T)

EV <- read.csv(dataset_list[1])

for (i in 2:length(dataset_list)) {
  
  set <- read.csv(dataset_list[i])
  
  EV <- left_join(EV, set)
  
  rm(i, set)
}

rm(dataset_list)

EV <- EV %>% select(lon, lat, all_of(variables))



scenarios_list <- list.dirs("./EV/proj_depth_limited", recursive = FALSE)

scenarios <- lapply(scenarios_list, function(dir){
  
  archivos <- list.files(dir, pattern = "\\.csv$", full.names = TRUE)
  
  lista_csv <- lapply(archivos, read.csv)
  
  df <- lista_csv[[1]][, c("lon", "lat")]
  
  for(i in seq_along(lista_csv)){
    datos <- lista_csv[[i]]
    
    df <- df %>% dplyr::left_join(datos, by = c("lon", "lat"))
    rm(datos)
  }
  
  df <- df %>% dplyr::select(lon, lat, all_of(variables))
  df
})

names(scenarios) <- basename(scenarios_list)

rm(variables)

# Modelling

not_modelled <- data.frame("Species"= NA)

i=9
for (i in 1:length(unique(Data_thin$Species))) {

  subset <- Data_thin %>% filter(Species == unique(Data_thin$Species)[i])
  
  if(nrow(subset)<30) {
    
    not_modelled <- rbind(not_modelled, unique(Data_thin$Species)[i])
   
  } else {
    
    # Choose background area (i.e.Existing accessible areas for invasive species - Buffer 500km around occurrences)
    
    pts <- st_as_sf(subset, coords = c("lon", "lat"), crs = 4326)
    pts <- st_transform(pts, 3857)
    buffer <- st_buffer(pts, dist = 500000)
    
    grid_pts <- EV[c(1,1,2,2)]
    grid_pts <- st_as_sf(grid_pts, coords = c("lon.1", "lat.1"), crs = 4326)
    grid_pts <- st_transform(grid_pts, 3857)
    
    grid <- st_filter(grid_pts, buffer)
    grid <- grid %>% st_drop_geometry()
    
    EV_grid <- EV %>% 
      semi_join(grid, by = c("lon", "lat"))
    
    
    rm(pts, buffer, grid_pts, grid)
    
    # Assign occurrences to raster cells when distance is less than x=10km
    
    subset$lon1 = subset$lon
    subset$lat1 = subset$lat
    subset_sf <- st_as_sf(subset, coords = c("lon1", "lat1"), crs = 4326)
    subset_sf <- st_transform(subset_sf, 3857)
    
    EV_grid$lon1 = EV_grid$lon
    EV_grid$lat1 = EV_grid$lat
    EV_sf <- st_as_sf(EV_grid, coords = c("lon1", "lat1"), crs = 4326)
    EV_sf <- st_transform(EV_sf, 3857)
    EV_sf <- EV_sf %>% mutate(rowid = row_number())
    
    nn <- RANN::nn2(st_coordinates(EV_sf), st_coordinates(subset_sf), k = 1)
    subset$dist_min <- nn$nn.dists[,1]
    subset$pixel_id  <- nn$nn.idx[,1]
    
    EV_sf <- EV_sf %>% 
      st_drop_geometry() %>%
      rename(lon_grid = lon, lat_grid = lat) 
    
    subset <- subset %>% select(-lon1, -lat1)
    
    subset <- left_join(subset, EV_sf, by=join_by("pixel_id"=="rowid"))
    
    subset <- subset %>% filter(dist_min < 10000)
    
    EV_grid <- EV_grid %>% select(-lon1, -lat1)
    
    rm(EV_sf, subset_sf, nn)
    
    # Formatting Data to Model species distribution
    
    EV_grid <- EV_grid %>%
      mutate(Occurrence = ifelse(paste(round(EV_grid$lon,6), round(EV_grid$lat,6)) %in% paste(round(subset$lon_grid,6), round(subset$lat_grid,6)), 
                                 1, NA))
    model_df <- EV_grid %>%
      filter(Occurrence == 1)
    
    temp <- EV_grid %>%
      filter(is.na(Occurrence)) %>%
      slice_sample(n=ifelse(round(nrow(EV_grid)) < 15000, round(nrow(EV_grid)), 15000)) # Background points = 15,000 / All M where dataset less than 15,000
      # slice_sample(n=min(round(nrow(EV_grid)/10, 0), 15000)) # Number of background points equal to 1/10 of the grid points of the accessible area (Max: 15.000pts)
    
    model_df <- rbind(model_df, temp)
    rm(temp)
    
    # Variable correlation (Remove variables highly correlated using VIF criteria. Correlation threshold = 0.8)
    vifcor <- usdm::vifcor(model_df %>% select(-lon,-lat,-Occurrence), th=0.8)
    model_df <- model_df %>%
      select(-vifcor@excluded)
    
    rm(vifcor)
    
    # Pre model for variable selection
    biomod_format <- BIOMOD_FormatingData(resp.var = model_df$Occurrence,
                                          resp.xy = model_df %>% select(lon,lat),
                                          expl.var = (model_df %>% select(-lon, -lat, -Occurrence)),
                                          resp.name = unique(Data_thin$Species)[i])
    
    biomod_param <- BIOMOD_ModelingOptions(MAXENT.Phillips = list(path_to_maxent.jar = 'D:/Modelado/Modelos/2_Maxent_3_4_1/maxent',
                                                                  product = FALSE, 
                                                                  threshold = FALSE,
                                                                  linear = TRUE,
                                                                  quadratic = TRUE,
                                                                  hinge = TRUE,
                                                                  betamultiplier = 1,
                                                                  maximumiterations = 1000))
    setwd("D:/Proyectos/EMODNET_DP3/Pre_Models")
    
    biomod_model <- BIOMOD_Modeling(data = biomod_format,
                                    models = c('MAXENT.Phillips'),
                                    models.options = biomod_param,
                                    NbRunEval = 3,
                                    DataSplit=75,
                                    Prevalence = 0.5, 
                                    VarImport = 5, 
                                    do.full.models = FALSE,
                                    models.eval.meth = c('TSS','ROC'))
    
    var_imp <- as.data.frame(get_variables_importance(biomod_model))
    var_imp <- var_imp %>%
      mutate(mean=rowMeans(.)) %>%
      filter(mean > 0.05) # Filter variables with less than 5% mean contribution in prelim models
    
    model_df <- model_df %>%
      select(lon, lat, Occurrence, rownames(var_imp))
    
    rm(var_imp, biomod_format, biomod_model)
    unlink("D:/Proyectos/EMODNET_DP3/Pre_Models", recursive = TRUE)
    
    # Model
    setwd("D:/Proyectos/EMODNET_DP3/Models_3")
    
    biomod_format <- BIOMOD_FormatingData(resp.var = model_df$Occurrence,
                                          resp.xy = model_df %>% select(lon,lat),
                                          expl.var = (model_df %>% select(-lon, -lat, -Occurrence)),
                                          resp.name = unique(Data_thin$Species)[i])
    
    biomod_model <- BIOMOD_Modeling(data = biomod_format,
                                    models = c('MAXENT.Phillips'),
                                    models.options = biomod_param,
                                    NbRunEval = 5,
                                    DataSplit=75,
                                    Prevalence = 0.5, 
                                    VarImport = 5, 
                                    do.full.models = FALSE,
                                    models.eval.meth = c('TSS','ROC'))
    
    evaluation <- get_evaluations(biomod_model)
    
    # Present Day Geographic Projections
    
    newenv <- EV %>%
      filter(lon>-20, lon<45, lat>30, lat<75) %>%
      select(names(model_df)[names(model_df) != "Occurrence"])
    
    biomod_projection <- BIOMOD_Projection(modeling.output = biomod_model,
                                           new.env = (newenv %>% select(-lon, -lat)),
                                           xy.new.env = (newenv %>% select(lon, lat)),
                                           proj.name = 'Historico',
                                           build.clamping.mask = FALSE,
                                           selected.models = 'all',
                                           binary.meth = c('TSS'))
    
    results <- as.data.frame(biomod_projection@xy.coord)
    results <- cbind(results, as.data.frame(biomod_projection@proj@val))
    
    umbrales <- setNames(as.numeric(evaluation[1, 2, 1, 1:5, 1]), names(results)[3:7])
    
    
    results <- results %>%
      mutate(
        across(
          .cols = all_of(names(umbrales)),
          .fns  =  ~ as.integer(.x > umbrales[cur_column()]),  # usa >= si debe incluir el umbral,
          .names = "{.col}_bin"
        )
      )
    
    write.csv(results, 
              paste0("./", gsub(" ", ".", unique(Data_thin$Species)[i]), "/",
                              gsub(" ", ".", unique(Data_thin$Species)[i]), "_models.csv"),
              row.names = F)
    
    rm(results, umbrales)
    
    # CC Scenarios Projections
    
    for (j in 1:length(scenarios)) {
      
      newenv <- scenarios[[j]] %>%
        filter(lon>-20, lon<45, lat>30, lat<75) %>%
        select(names(model_df)[names(model_df) != "Occurrence"])
      
      biomod_projection <- BIOMOD_Projection(modeling.output = biomod_model,
                                             new.env = (newenv %>% select(-lon, -lat)),
                                             xy.new.env = (newenv %>% select(lon, lat)),
                                             proj.name = names(scenarios)[j],
                                             build.clamping.mask = FALSE,
                                             selected.models = 'all',
                                             binary.meth = c('TSS'))
      results <- as.data.frame(biomod_projection@xy.coord)
      results <- cbind(results, as.data.frame(biomod_projection@proj@val))
      
      umbrales <- setNames(as.numeric(evaluation[1, 2, 1, 1:5, 1]), names(results)[3:7])
      
      
      results <- results %>%
        mutate(
          across(
            .cols = all_of(names(umbrales)),
            .fns  =  ~ as.integer(.x > umbrales[cur_column()]),  # usa >= si debe incluir el umbral,
            .names = "{.col}_bin"
          )
        )
      
      write.csv(results, 
                paste0("./", gsub(" ", ".", unique(Data_thin$Species)[i]), "/",
                       gsub(" ", ".", unique(Data_thin$Species)[i]),"_", names(scenarios)[j], "_models.csv"),
                row.names = F)
      
      rm(results, umbrales, j)
      
    }
    
    rm(biomod_format, biomod_model, biomod_param, biomod_projection, i,
       EV_grid, model_df, newenv, results, subset, evaluation, umbrales)
  }
}
