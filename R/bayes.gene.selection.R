bayes.gene.selection <- function(n_sigGene, dat, trainingLabel, iter=500,
                                 burn_in=100, sigmaZero = 0.1, sigmaNonZero = 1,
                                 alpha_tau = 1, beta_tau = 0.01, p = 0.01,
                                 pctUp=0.5, anchorGenes=NULL,
                                 excludeGenes=NULL){
  nPath <- length(trainingLabel) - 1
  bgPosB <- NULL; edPosB <- NULL
  for (i in 1:length(trainingLabel[[1]])){
    bgPosB <- c(bgPosB, trainingLabel[[1]][[i]][1])
    edPosB <- c(edPosB, trainingLabel[[1]][[i]][length(trainingLabel[[1]][[i]])])
  }
  bgPosS <- NULL; edPosS <- NULL
  for (i in 2:length(trainingLabel)){
    bgPosS <- c(bgPosS, trainingLabel[[i]][1])
    edPosS <- c(edPosS, trainingLabel[[i]][length(trainingLabel[[i]])])
  }
  m <- nPath  # pathways
  n <- NROW(dat)  # genes
  B_pos <- matrix(0, n, m)
  S_pos <- matrix(0, n, m)
  r_pos <- matrix(0, n, m)
  tau2_pos <- matrix(0, n, m)

  for (j in 1: m){
    message("Gene selection on ", names(trainingLabel)[j + 1], " pathway...")
    Y <- dat[, c(bgPosB[j]:edPosB[j], bgPosS[j]:edPosS[j])]
    k <- NCOL(Y)
    k1 <- edPosB[j] - bgPosB[j] + 1
    k2 <- edPosS[j] - bgPosS[j] + 1
    sigma1 <- sigmaZero #need to be modified!!!
    sigma2 <- sigmaNonZero
    u <- alpha_tau
    v <- beta_tau

    PHI_B <- matrix(nrow = iter, ncol = n)
    PHI_S <- matrix(nrow = iter, ncol = n)
    PHI_Delta <- matrix(nrow = iter, ncol = n)
    PHI_tau2 <- matrix(nrow = iter, ncol = n)

    PHI_B[1, ] <- rep(0, n)
    PHI_S[1, ] <- rep(0, n)
    PHI_Delta[1, ] <- rep(0, n)
    PHI_tau2[1, ] <- rep(u / v, n)
    pb <- utils::txtProgressBar(min = 0, max = iter, width = 80, file = stderr())
    message("| 0%                                  50%",
            "                                 100% |")
    for (i in 2:iter){
      utils::setTxtProgressBar(pb, i)
      s_B_1 <- 1 / (k * PHI_tau2[i - 1, ] + 1 / sigma2 ^ 2)
      mu_B_1 <- s_B_1 * (apply(Y, 1, sum) - k2 * PHI_S[i - 1, ]) * PHI_tau2[i - 1, ]
      PHI_B[i, ] <- stats::rnorm(n, mu_B_1, sapply(s_B_1, sqrt))

      a <- ifelse(PHI_Delta[i - 1, ] == 1, sigma2, sigma1)
      s_beta_1 <- 1 / (k2 * PHI_tau2[i - 1, ] + 1 / a ^ 2)
      mu_beta_1 <- s_beta_1 * (apply(Y[, (k1 + 1):k], 1, sum) - k2 * PHI_B[i, ]) * PHI_tau2[i - 1, ]
      PHI_S[i, ] <- stats::rnorm(n, mu_beta_1, sapply(s_beta_1, sqrt))

      b_div_a <- (1 - p) / p * (sigma2 / sigma1) * exp(-1 / 2 * (PHI_S[i, ] ^ 2 / sigma1 ^ 2 - PHI_S[i, ] ^ 2 / sigma2 ^ 2))
      PHI_Delta[i, ] <- Rlab::rbern(n, 1 / (1 + b_div_a))

      un <- u + k / 2
      sum1 <- apply((Y[, 1:k1] - matrix(rep(PHI_B[i, ], k1), n, k1)) ^ 2, 1, sum)
      sum2 <- apply((Y[, (k1 + 1):k] - matrix(rep((PHI_B[i, ] + PHI_S[i, ]), k2), n, k2)) ^ 2, 1, sum)
      vn <- (sum1 + sum2) / 2 + v
      PHI_tau2[i, ] <- Rlab::rgamma(n, un, vn)

    }
    close(pb)
    B_pos[, j] <- apply(PHI_B[-c(1:burn_in), ], 2, mean)
    S_pos[, j] <- apply(PHI_S[-c(1:burn_in), ], 2, mean)
    r_pos[, j] <- apply(PHI_Delta[-c(1:burn_in), ], 2, mean)
    tau2_pos[, j] <- apply(PHI_tau2[-c(1:burn_in), ], 2, mean)
  }

  diffGeneList <- vector("list")
  for (j in 1:m){
    if(!is.null(excludeGenes[[j]])){
      excludegene_index <- which(row.names(dat) %in% excludeGenes[[j]])
    } else{
      excludegene_index <- NULL
    }
    #check if we are excluding more genes than are available for signature
    if(length(setdiff(order((abs(S_pos[, j]) * r_pos[, j]), decreasing = TRUE),
                      excludegene_index)) < n_sigGene[j]){
      stop("There aren't enough genes available in the data. ",
           "Check excludeGenes and n_sigGene.")
    }
    if (!is.null(pctUp)){
      tmp_up   <- setdiff(order((S_pos[, j] * r_pos[, j]), decreasing = TRUE),
                          excludegene_index)[1:floor(n_sigGene[j] / (1 / (pctUp)))]
      tmp_down <- setdiff(order((S_pos[, j] * r_pos[, j]), decreasing = FALSE),
                          excludegene_index)[1:ceiling(n_sigGene[j] / (1 / (1 - pctUp)))]
      tmp <- c(tmp_up, tmp_down)
    }
    else{
      tmp <- setdiff(order((abs(S_pos[, j]) * r_pos[, j]), decreasing = TRUE),
                     excludegene_index)[1:n_sigGene[j]]
    }
    diffGeneList[[j]] <- row.names(dat)[tmp]
  }
  return(list(prior_p = r_pos, beta1 = S_pos, diffGeneList = diffGeneList))
}
