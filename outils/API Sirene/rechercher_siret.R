####
# rechercher_siret.R
#
# Fonction outil pour faciliter la recherche
# multicrit�res de siret sur l'API-Sirene 
# (cf. documentation API-Sirene pp. 25-29)
#
# Martin Chevalier (Insee-DMS)
# 03/12/2017
# Version 0.2
####

# REMARQUE : Code encore non-test� en d�tail, 
# n'h�sitez pas � proposer des am�liorations avant,
# pendant ou apr�s le hackathon !

# Configuration du proxy Insee
# file.edit("~/.Renviron")
# http_proxy=proxy-rie.http.insee.fr:8080
# https_proxy=proxy-rie.http.insee.fr:8080


#' Effectuer une recherche multicrit�res de siret
#' 
#' @param q Un vecteur caract�re de longueur 1, code de la requ�te 
#' multicrit�res (cf. documentation API-Sirene, pp. 25-29)
#' @param nombre Un vecteur entier de longueur 1 (100 par d�faut), 
#' nombre d'�tablissements � r�cup�rer en une requ�te 
#' (cf. documentation API-Sirene p. 29)
#' @param url Un vecteur caract�re de longueur 1 
#' (https://prototype.api-sirene.insee.fr/ws/siret par d�faut),
#' URL du service de recherche de siret de l'API-Sirene
#' @param progress Un vecteur logique de longueur 1 (TRUE par d�faut),
#'  afficher ou non la progresion de la recherche

#' @return Un data.frame avec en ligne les �tablissements extraits 
#' et en colonne leurs caract�ristiques.


rechercher_siret <- function(
  q
  , nombre = 100
  , url = "https://prototype.api-sirene.insee.fr/ws/siret"
  , progress = TRUE
){

  # Etape 0 : Chargement des packages n�cessaires
  if(!suppressWarnings(require(httr)) | !suppressWarnings(require(jsonlite)))
    stop("Les packages httr et jsonlite sont n�cessaires. Utilisez install.packages(c(\"httr\", \"jsonlite\")) pour les installer ainsi que leurs d�pendances.")

  # Etape 1 : Envoi des requ�tes sur l'API et conversion en liste R
  Curseur <- ""; CurseurSuivant <- "*"; resultat <- list(); num_requete <- 1
  if(progress) message("Envoi des requ�tes (chacune r�cup�re ", nombre, " observations) : ", appendLF = FALSE)
  while(CurseurSuivant != Curseur){
    if(progress) message(if(num_requete %% 10 > 0) "." else num_requete, appendLF = FALSE)
    requete <- paste0(url, "?q=", q, "&curseur=", CurseurSuivant, "&nombre=", nombre)
    reponse_json <- GET(requete)
    reponse_list <- fromJSON(content(reponse_json, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
    resultat[[length(resultat) + 1]] <- reponse_list
    Curseur <- reponse_list$Header$Curseur
    CurseurSuivant <- reponse_list$Header$CurseurSuivant
    if(CurseurSuivant == Curseur){if(progress & num_requete %% 10 > 0) message(num_requete)} else 
      num_requete <- num_requete + 1
  }
  cat("\n")

  # Etape 2 : Mise en forme dans un data.frame

  # Etape 2.1 : Mise � plat des listes par siret
  out <- do.call(base::c, lapply(resultat, `[[`, "Etablissements"))
  out <- lapply(out, function(x) lapply(
    c(x[1:5], x[["UniteLegale"]], x[["Adresse"]], x[["Periodes"]][[1]])
    # ATTENTION : on fait l'hypoth�se ici qu'il n'y a qu'une seule p�riode
    , function(x) if(is.null(x)) NA else x
  ))

  # Etape 2.2 Traitement des exceptions
  for(var in c("UnitePurgee", "Doublon")){
    out <- lapply(out, function(x){
      if(!(var %in% names(x))) c(x, setNames(list(NA), var)) else
        c(x[setdiff(names(x), var)], x[var])
    })
  }

  # Etape 2.3 : Permutation des dimensions de la liste 
  # et transformation en data.frame
  out <- as.data.frame(lapply(
    setNames(seq_along(out[[1]]), names(out[[1]]))
    , function(i) sapply(out, `[[`, i)
  ), stringsAsFactors = FALSE)
  
  return(out)
  
}

# Reprise de l'exemple du tutoriel propos� � l'adresse
# https://github.com/SSP-Lab/Hackathon-2018/blob/master/outils/API%20Sirene/r-nb-tuto-api-sirene.Rmd
# df <- rechercher_siret("Denomination:notaire")
# str(df)
