# Hotspots of invasive macroalgae in European coasts using stacked-SDMs

## Introduction

The increasing introduction and spread of non-native marine macroalgae in European waters pose significant threats to biodiversity, ecosystem functioning and economic activities. Identifying areas with a high potential risk of invasion is therefore essential for developing effective monitoring and management strategies. Species distribution models (SDMs) provide a valuable framework for predicting the environmental suitability of marine species and identifying areas where non-native species may establish and spread. However, modelling multiple invasive species simultaneously remains challenging due to differences in species' ecological requirements, data availability and model performance. This product aims to develop a stacked species distribution modelling (S-SDM) approach to predict the potential distribution of invasive macroalgae in Europe and identify geographic hotspots where environmental suitability for multiple invasive species overlaps. By combining species-level predictions into a single spatial framework, the approach provides an integrated assessment of invasion risk and supports the identification of priority areas for early detection, monitoring and management.

## Directory structure

```
/

├── product/
└── scripts/
```

* **product** - Output product files
* **scripts** - Reusable code

## Data series

The data series used in this product have been downoladed from EMODnet Biology, EMODnet Bathymetry, EMODnet Seabed Habitats, OBIS, GBIF and Bio-Oracle. The scripts used to obtain this data are included here:
(01_Download_Presences.R)
(02_Download_Variables.R)

## Data product

This dataset comprises raster maps representing potential hotspots and coldspots of invasive marine macroalgae across European waters. Pixel values provide a proxy of potential invasive species richness, derived by combining species-specific habitat suitability maps through a stacked species distribution modelling (S-SDM) approach. For each species, habitat suitability was modelled independently based on its environmental requirements, and the resulting predictions were subsequently stacked to estimate the potential richness of invasive macroalgae at each spatial location.

The resulting richness estimates represent the potential number of invasive species that may find environmentally suitable conditions at a given location. Therefore, they should not be interpreted as estimates of observed, established, or currently occurring invasive species richness. Instead, they reflect the degree of environmental suitability for the modelled invasive species and can be used to identify areas with comparatively high or low potential invasion pressure.

Predictions were generated under current environmental conditions ('Present') and projected under future climate conditions based on four CMIP6 climate scenarios: SSP2-4.5 and SSP5-8.5, representing intermediate and high greenhouse gas emission pathways, respectively. Future projections are provided for both mid-century (2050-01-01) and end-of-century (2100-01-01) periods, allowing potential changes in the spatial distribution of invasive macroalgae hotspots and coldspots under climate change to be assessed.

## More information:

### References

de la Hoz, C.F., Ramos, E., Puente, A., Juanes, J.A. 2019. Temporal transferability of marine distribution models: The role of algorithm selection. Ecological Indicators, 106, 105499.

Sainz-Villegas, S., de la Hoz, C.F., Juanes, J.A., Puente, A. 2022. Predicting non-native seaweeds global distributions: The importance of tuning individual algorithms in ensembles to obtain biologically meaningful results. Frontiers in Marine Science, 9, 1009808.

### Code and methodology

The methodology consists of stacked SDMs. The SDMs were Maximum entropy models (MAXENT). Previous research on invasive and non-invasive species models highlighted the relevance of tuning model configuration settings to achieve better results (e.g. de la Hoz et al., 2019; Sainz-Villegas et al., 2022). Background points (Max. 15.000, depending on species) were selected from existing accessible areas for invasive species, in this case as a buffer of 500km around occurrences. Environmental variables were selected from a pre-established pool of 13 environmental variables. Only non-correlated variables were selected (< 0.8 Pearson correlation coefficient). From those correlated, the one with the highest VIF was removed. A preliminar MAXENT model was also developed for variable selection. Variables with less than 5% contribution were removed. Models inluded linear, quadratic and hinge features. Other options were set to default (in biomod2 R package, v. 3.5.1).

Model implementation can be found in:
-	03_Models.R
-	04_Stacked_Values.R

### Citation and download link

This product should be cited as:

Ramos, E., Sainz-Villegas, S., de la Hoz, C.F., Puente, A., Juanes, J.A. (2026) Hotspots of invasive macroalgae in European coasts using stacked-SDMs. Data product created under the European Marine Observation Data Network (EMODnet) Biology Phase V.

Available to download in:

EMODnet catalogue=> 
VLIZ catalogue=> 
EMODnet ERDDAP file=> 
EMODnet viewer=> 


### Authors

Ramos, E., Sainz-Villegas, S., de la Hoz, C.F., Puente, A., Juanes, J.A. 
