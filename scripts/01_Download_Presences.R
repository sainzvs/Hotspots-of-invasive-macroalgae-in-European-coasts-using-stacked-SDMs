rm(list=ls())

packages <- c("openxlsx", "dplyr", "emodnet.wfs", "spocc", "worrms")

for(p in packages){
  if(!requireNamespace(p, quietly = TRUE)){
    install.packages(p)
  }
}

rm(p, packages)

library(dplyr)
library(emodnet.wfs)
library(spocc)


setwd("D:/Proyectos/EMODNET_DP3")

# Load species names from invasive species list
Data <- openxlsx::read.xlsx("./Listado/Listado_especies.xlsx", sheet = 3)

#Get aphiaID
species_match1 <- worrms::wm_records_taxamatch(Data$Especies[1:50])
species_match1 <- do.call(rbind, species_match1)
species_match2 <- worrms::wm_records_taxamatch(Data$Especies[51:100])
species_match2 <- do.call(rbind, species_match2)
# species_match3 <- worrms::wm_records_taxamatch(Data$Especies[101])
# species_match3 <- do.call(rbind, species_match3)
species_match <- rbind(species_match1, species_match2)#, species_match3)
rm(species_match1, species_match2)#, species_match3)

Data <- left_join(Data, species_match, by=join_by(Especies==scientificname))
Data <- unique(Data)
Data <- Data %>%
  filter(!is.na(valid_AphiaID))
rm(species_match)


# Download presence records
wfs=emodnet_init_wfs_client("biology_occurrence_data")

df <- data.frame("species"=NA,"AphiaID"=NA,"lon"=NA, "lat"=NA)

i=1
for (i in 1:length(unique(Data$valid_AphiaID))) {
  
  #Species name
  species <- Data %>% 
    filter(valid_AphiaID == unique(Data$valid_AphiaID)[i]) %>%
    select(valid_name, valid_AphiaID)
  
  #Download records from emodnet
  
  query = paste0("aphiaid%3A", species$valid_AphiaID[1])
  emodnet <- emodnet_get_layers(
    wfs,
    layers = "eurobis-obisenv_basic",
    viewParams = query,
    simplify = FALSE)
  
  emodnet <- as.data.frame(emodnet$`eurobis-obisenv_basic`)
  emodnet <- emodnet %>%
    select(scientificnameaccepted, decimallongitude, decimallatitude) %>%
    rename(species=scientificnameaccepted, lon=decimallongitude, lat=decimallatitude)
  emodnet <- emodnet[!is.na(emodnet$lon), ]
  
  rm(query)
  
  #Download records from GBIF
  
  gbif_opt <- list(basisOfRecord = "HUMAN_OBSERVATION", occurrenceStatus = "Present")
  
  
  gbif<- occ(query = species$valid_name[1], from = c('gbif'), limit = 30000, gbifopts = gbif_opt)
  gbif <- occ2df(gbif)
  gbif <- gbif[!is.na(gbif$longitude), ]
  
  
  if (dim(emodnet)[1] != 0 & dim(gbif)[1] != 0) {
    
    emodnet$species <- species$valid_name[1]
    emodnet$AphiaID <- species$valid_AphiaID[1]
    emodnet <- emodnet[c(1,4,2,3)]
    
    gbif <- dplyr::select(gbif, name, longitude, latitude) 
    gbif <- gbif %>%
      rename(species=name, lon=longitude, lat=latitude)
    gbif$species <- species$valid_name[1]
    gbif$AphiaID <- species$valid_AphiaID[1]
    gbif <- gbif[c(1,4,2,3)]
    
    df <- rbind(df,emodnet, gbif)
    
  } else if (dim(emodnet)[1] != 0 & dim(gbif)[1] == 0) {
    
    emodnet$species <- species$valid_name[1]
    emodnet$AphiaID <- species$valid_AphiaID[1]
    emodnet <- emodnet[c(1,4,2,3)]
    
    cat(paste("no data in gbif for", species[1], "; "))
    
    df <- rbind(df,emodnet)
    
  } else if (dim(emodnet)[1] == 0 & dim(gbif)[1] != 0) {
    
    cat(paste("no data in emodnet for", species[1], "; "))
    
    gbif <- dplyr::select(gbif, name, longitude, latitude) 
    gbif <- gbif %>%
      rename(species=name, lon=longitude, lat=latitude)
    gbif$species <- species$valid_name[1]
    gbif$AphiaID <- species$valid_AphiaID[1]
    gbif <- gbif[c(1,4,2,3)]
    
    df <- rbind(df, gbif) 
    
    }  else if (dim(emodnet)[1] == 0 & dim(gbif)[1] == 0) {
    
      cat(paste("no data in emodnet or gbif for", species[1], "; "))  
  
  }
  
  rm(emodnet, species, gbif_opt, gbif, i)
  
}

rm(Data, wfs)

df <- df[-1,]
df <- na.omit(df)
df <- df[!duplicated(df), ]

# Save presences in a dataset (csv format)
write.csv(df, "./Ocurrencias/Ocurrencias.csv", row.names = F)
