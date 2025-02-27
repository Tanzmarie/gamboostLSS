cvrisk.nc_mboostLSS <- function(object, folds = cv(model.weights(object)),
                                grid = 1:sum(mstop(object)),
                                papply = mclapply, trace = TRUE, 
                                mc.preschedule = FALSE, fun = NULL, ...) {
    
    weights <- model.weights(object)
    if (any(weights == 0))
        warning("Zero weights in ", sQuote("object"))
    if (is.null(folds)) {
        folds <- rmultinom(25, length(weights), weights/sum(weights))
    } else {
        stopifnot(is.matrix(folds) && nrow(folds) == length(weights))
    }
    
    if (!is.null(fun))
        stopifnot(is.function(fun))
    
    ### WHAT ABOUT:
    ## fam_name <- object$family@name
    call <- deparse(attr(object, "call"))
    oobrisk <- matrix(0, nrow = ncol(folds), ncol = length(grid))
    if (trace)
        cat("Starting cross-validation...")
    if (is.null(fun)) {
        dummyfct <- function(i, weights, oobweights) {
            if (trace)
                cat("\n[Fold: ", i, "]\n", sep = "")
            ## make model with new weights and max mstop
            mod <- update(object, weights = weights, oobweights = oobweights,
                          risk = "oobag",
                          mstop = max(grid), trace = trace)
            
            
            risks <- attr(mod, "combined_risk")()[grid]
            names(risks) <- grid
            risks
            
        }
    }
    else {
        stop("currently not implemented")
    }
    
    OOBweights <- matrix(rep(weights, ncol(folds)), ncol = ncol(folds))
    OOBweights[folds > 0] <- 0
    if (identical(papply, mclapply)) {
        oobrisk <- papply(1:ncol(folds),
                          function(i) dummyfct(i = i,
                                               weights = folds[, i],
                                               oobweights = OOBweights[, i]),
                          mc.preschedule = mc.preschedule,
                          ...)
    } else {
        oobrisk <- papply(1:ncol(folds),
                          function(i) try(dummyfct(i = i,
                                                   weights = folds[, i],
                                                   oobweights = OOBweights[, i])),
                          ...)
    }
    ## if any errors occured remove results and issue a warning
    if (any(idx <- sapply(oobrisk, is.character))) {
        warning(sum(idx), " fold(s) encountered an error. ",
                "Results are based on ", ncol(folds) - sum(idx),
                " folds only.\n",
                "Original error message(s):\n",
                sapply(oobrisk[idx], function(x) x))
        oobrisk[idx] <- NULL
    }
    if (!is.null(fun))
        return(oobrisk)
    oobrisk <- t(as.data.frame(oobrisk))
    oobrisk <- oobrisk / colSums(OOBweights)
    colnames(oobrisk) <- grid
    rownames(oobrisk) <- 1:nrow(oobrisk)
    #attr(oobrisk, "risk") <- fam_name
    attr(oobrisk, "call") <- call
    attr(oobrisk, "mstop") <- grid
    attr(oobrisk, "type") <- ifelse(!is.null(attr(folds, "type")),
                                    attr(folds, "type"), "user-defined")
    class(oobrisk) <- c("nc_cvriskLSS", "cvrisk")
    oobrisk
}


risk.nc_mboostLSS <- function(object, merge = FALSE, 
                              parameter = names(object), ...){
    
    if(merge) attr(object, "combined_risk")()
    else{
        risk.mboostLSS(object, merge = FALSE, parameter = names(object), ...)
    }
    
}


plot.nc_cvriskLSS <- function(x, xlab = "Number of boosting iterations", ylab = NULL,
                              ylim = range(x),
                              main = attr(x, "type"),
                              ...) {
    dots <- list(...)
    if ("type" %in% names(dots) && dots$type != "lines")
        warning("Only ", sQuote('type = "lines"'), " supported for noncyclical fitting")
    plot.cvriskLSS(x = x, type = "lines", xlab = xlab, ylab = ylab, 
                    ylim = ylim, main = main, ...)
}

