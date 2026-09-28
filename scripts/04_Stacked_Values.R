rm(list=ls())

packages <- c("sf", "biomod2", "ggplot2", "dplyr")

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

species <- list.files("./Models_3")
species <- species[c(1,4,7,9,10,12,13,14,15,16,17,21,22,23,24,26,27,28,31,36,37,40,42,43,46,48,49,55)] # Removes species with low quality models (i.e. non reliable projections)

models <- read.csv(paste0("./Models_3/", species[1], "/", species[1], "_models.csv"))

models <- models %>%
  mutate(model = rowMeans(.[,c(3:7)], na.rm = TRUE),
         model_bin = if_else(rowSums(across(8:12) == 1) == 5, 1, 0))

models <- models[names(models) %in% c("lon", "lat", "model", "model_bin")]
names(models)[3] <- paste0(species[1], "_model")
names(models)[4] <- paste0(species[1], "_bin")

i=2
for (i in 2:length(species)) {
  
  temp <- read.csv(paste0("./Models_3/", species[i], "/", species[i], "_models.csv"))
  
  temp <- temp %>%
    mutate(model = rowMeans(.[,c(3:7)], na.rm = TRUE),
           model_bin = if_else(rowSums(across(8:12) == 1) == 5, 1, 0))
  
  temp <- temp[names(temp) %in% c("lon", "lat", "model", "model_bin")]
  names(temp)[3] <- paste0(species[i], "_model")
  names(temp)[4] <- paste0(species[i], "_bin")
  
  models <- left_join(models, temp)
  
  rm(temp,i)
  
}


models <- models %>%
  mutate(Richness = rowSums(across(contains("model"))/1000, na.rm = TRUE))

models <- models %>%
  mutate(Richness_bin = rowSums(across(contains("_bin")), na.rm = TRUE))

quantiles <- quantile(models$Richness, probs = c(0.1, 0.9))

models <- models %>%
  mutate(Type = ifelse(Richness < quantiles[[1]], "coldspot", ifelse(Richness > quantiles[[2]], "hotspots", "normal"))) %>%
  mutate(Type = as.factor(Type))

models %>%
  # filter(Richness_bin > 1) %>%
  ggplot() +
  geom_raster(aes(x=lon, y=lat, fill=Richness))

models <- models %>% 
  select(lon, lat, Richness, Richness_bin, Type)

write.csv(models, 
          paste0("./Stacked_3/", "Stacked_Results.csv"),
          row.names = F)

# Climate change
scenarios <- c("Scenario_1", "Scenario_2", "Scenario_3", "Scenario_4")

j=1
for (j in 1:length(scenarios)){
  
  proj <- read.csv(paste0("./Models_3/", species[1], "/", species[1], "_", scenarios[j],"_models.csv"))
  
  proj <- proj %>%
    mutate(model = rowMeans(.[,c(3:7)], na.rm = TRUE),
           model_bin = if_else(rowSums(across(8:12) == 1) == 5, 1, 0))
  
  proj <- proj[names(proj) %in% c("lon", "lat", "model", "model_bin")]
  names(proj)[3] <- paste0(species[1], "_model")
  names(proj)[4] <- paste0(species[1], "_bin")
  
  for (k in 2:length(species)) {
    
    temp <- read.csv(paste0("./Models_3/", species[k], "/", species[k],"_", scenarios[j], "_models.csv"))
    
    temp <- temp %>%
      mutate(model = rowMeans(.[,c(3:7)], na.rm = TRUE),
             model_bin = if_else(rowSums(across(8:12) == 1) == 5, 1, 0))
    
    temp <- temp[names(temp) %in% c("lon", "lat", "model", "model_bin")]
    names(temp)[3] <- paste0(species[k], "_model")
    names(temp)[4] <- paste0(species[k], "_bin")
    
    proj <- left_join(proj, temp)
    
    rm(temp,k)
    
  }
  
  proj <- proj %>%
    mutate(Richness = rowSums(across(contains("model"))/1000, na.rm = TRUE))
  
  proj <- proj %>%
    mutate(Richness_bin = rowSums(across(contains("_bin")), na.rm = TRUE))
  
  quantiles <- quantile(proj$Richness, probs = c(0.01, 0.99))
  
  proj <- proj %>%
    mutate(Type = ifelse(Richness < quantiles[[1]], "coldspot", ifelse(Richness > quantiles[[2]], "hotspots", "normal"))) %>%
    mutate(Type = as.factor(Type))
  
  proj <- proj %>%
    select(lon, lat, Richness, Richness_bin, Type)
  
  write.csv(proj, 
            paste0("./Stacked_3/", "Stacked_Results_", scenarios[j], ".csv"),
            row.names = F)
  
  rm(proj, j)
}


