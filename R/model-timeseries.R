#' Time-series models in Zelig
#'
#' @import methods
#' @export Zelig-timeseries
#' @exportClass Zelig-timeseries
#'
#' @include model-zelig.R
ztimeseries <- setRefClass("Zelig-timeseries",
                    contains = "Zelig",
                    fields = list(link = "character",
                                  linkinv = "function"))


ztimeseries$methods(
  initialize = function() {
    callSuper()
    .self$packageauthors <- "R Core Team"
    .self$modelauthors <- "James Honaker"
    .self$acceptweights <- FALSE  #  Need to deal with block bootstrap
    .self$category <- "timeseries"
    .self$setx.labels <- list(ev  = "Expected Values: E(Y|X)",
                              ev1 = "Expected Values: E(Y|X1)",
                              pv  = "Predicted Values: Y|X",
                              pv1 = "Predicted Values: Y|X1",
                              fd  = "First Differences: E(Y|X1) - E(Y|X)",
                              acf = "Autocorrelation Function",
                              ev.shortrun = "Expected Values Immediately Resulting from Shock",
                              ev.longrun = "Long Run Expected Values after Innovation",
                              pv.shortrun = "Predicted Values Immediately Resulting from Shock",
                              pv.longrun = "Long Run Predicted Values after Innovation",
                              evseries.shock = "Expected Values Over Time from Shock",
                              evseries.innovation ="Expected Values Over Time from Innovation",
                              pvseries.shock = "Predicted Values Over Time from Shock",
                              pvseries.innovation ="Predicted Values Over Time from Innovation")
    warning("++++ All Zelig time series models will be deprecated on 1 February 2018 ++++",
            call. = FALSE)
  }
)

ztimeseries$methods(
  zelig = function(formula, data, order = c(1, 0, 0), ts = NULL, cs = NULL, ...,
                   weights = NULL, by = NULL, bootstrap = FALSE){

    localBy <- by     # avoids CRAN warning about deep assignment from by existing separately as argument and field

    if (identical(class(data), "function"))
        stop("data not found.", call. = FALSE)
    else
        localData <- data # avoids CRAN warning about deep assignment from data existing separately as argument and field

    if(!identical(bootstrap, FALSE)){
         stop("Error: The bootstrap is not implemented for time-series models",
              call. = FALSE)
    }
    if (!is.null(cs) && is.null(ts))
        stop("ts must be specified if cs is specified.", call. = FALSE)
    if (!is.null(cs) && !is.null(by)) {
            stop("cs and by are equivalent for this model. Only one needs to be specified.",
                 call. = FALSE)
    }

    .self$zelig.call <- match.call(expand.dots = TRUE)
    if(identical(.self$name,"ar")){
      order <- c(1,0,0)
      .self$zelig.call$order <- order
    } else if(identical(.self$name,"ma")){
      order <- c(0,0,1)
      .self$zelig.call$order <- order
    } else {
        dots <- list(...)
        if (!is.null(dots$order)) {
            order <- dots$order
        }
        .self$zelig.call$order <- order
    }
    .self$model.call <- .self$zelig.call

    ## Sort dataset by time and cross-section
    ## Should add checks that ts, cs, are valid, and consider how to interact with by.
    ## This follows handling from Amelia::prep.r, which also has code to deal with lags, should we add those.
    if(!is.null(ts)){
      .self$model.call$ts <- NULL
      if (!is.null(cs)) {
        .self$model.call$cs <- NULL
        tsarg<-list(localData[,cs],localData[,ts])
        localBy <- cs  # Use by architecture to deal with cross-sections in time-series models that do not support such.  Currently overrides.
      } else {
        tsarg<-list(localData[,ts])
      }

      tssort <- do.call("order",tsarg)
      localData <- localData[tssort,]
    }

    ## ts and cs are used to reorganize dataset, and do not get further passed on to Super
    callSuper(formula = formula, data = localData, order=order, ...,
              weights = weights, by = localBy, bootstrap = FALSE)
  }
)

# replace packagename method as stats::arima() has a second layer of wrapping in zeligArimaWrapper().

ztimeseries$methods(
  packagename = function() {
    "Automatically retrieve wrapped package name"
    return("stats")
  }
)


# replace simx method to add ACF as QI.

ztimeseries$methods(
  simx = function() {
    base_vals <- .self$set() # generate mm of all averages

    d <- zelig_mutate(.self$zelig.out, simparam = .self$simparam$simparam)
    d <- zelig_mutate(d, mm = base_vals$mm)
    d <- zelig_mutate(d, mm1 = .self$setx.out$x$mm)


    .self$sim.out$x <-  d %>%
        do(qi = .self$qi(.$simparam, .$mm, .$mm1)) %>%
        do(acf = .$qi$acf,
           ev = .$qi$ev,
           pv = .$qi$pv,
           ev.shortrun = .$qi$ev.shortrun,
           pv.shortrun = .$qi$pv.shortrun,
           ev.longrun = .$qi$ev.longrun,
           pv.longrun = .$qi$pv.longrun,
           pvseries.shock = .$qi$pvseries.shock,
           evseries.shock = .$qi$evseries.shock,
           pvseries.innovation = .$qi$pvseries.innovation,
           evseries.innovation = .$qi$evseries.innovation)

    d <- zelig_mutate(.self$sim.out$x, ev0 = .self$sim.out$x$ev)    # Eventually, when ev moves, then this path for ev0 changes.  (Or make movement happen after fd calculation.)
    d <- d %>%
        do(fd = .$ev.longrun - .$ev0)
    .self$sim.out$x <- zelig_mutate(.self$sim.out$x, fd = d$fd) #JH
  }
)

ztimeseries$methods(
  simx1 = function() {
    d <- zelig_mutate(.self$zelig.out, simparam = .self$simparam$simparam)
    d <- zelig_mutate(d, mm = .self$setx.out$x$mm)
    d <- zelig_mutate(d, mm1 = .self$setx.out$x1$mm)

#      return(list(acf = acf, ev = ev, pv = pv, pv.shortrun=pv.shortrun, pv.longrun=pv.longrun, ev.shortrun=ev.shortrun, ev.longrun=ev.longrun,
#                pvseries.shock=yseries$y.shock, pvseries.innovation=yseries$y.innovation,
#                evseries.shock=yseries$ev.shock, evseries.innovation=yseries$ev.innovation))

    .self$sim.out$x1 <-  d %>%
      do(qi = .self$qi(.$simparam, .$mm, .$mm1)) %>%
      do(acf = .$qi$acf,
         ev = .$qi$ev,
         pv = .$qi$pv,
         ev.shortrun = .$qi$ev.shortrun,
         pv.shortrun = .$qi$pv.shortrun,
         ev.longrun = .$qi$ev.longrun,
         pv.longrun = .$qi$pv.longrun,
         pvseries.shock = .$qi$pvseries.shock,
         evseries.shock = .$qi$evseries.shock,
         pvseries.innovation = .$qi$pvseries.innovation,
         evseries.innovation = .$qi$evseries.innovation)
      # Will eventually have to then move acf, ev, and pv from .self$setx.out$x1 to .self$setx.out$x
      # This will also effect next line:

    d <- zelig_mutate(.self$sim.out$x1, ev0 = .self$sim.out$x1$ev)    # Eventually, when ev moves, then this path for ev0 changes.  (Or make movement happen after fd calculation.)
    d <- d %>%
      do(fd = .$ev.longrun - .$ev0)
    .self$sim.out$x1 <- zelig_mutate(.self$sim.out$x1, fd = d$fd) #JH
  }
)

# replace sim method to skip {simx, simx1, simrange, simrange1} methods as they are not separable
# instead go directly to qi method

ztimeseries$methods(
  sim = function(num = 1000) {
    "Timeseries Method for Computing and Organizing Simulated Quantities of Interest"
    if (length(.self$num) == 0)
      .self$num <- num
    .self$simparam <- .self$zelig.out %>%
      do(simparam = .self$param(.$z.out))

    # NOTE difference here from standard Zelig approach.
    # Normally these are done in sequence, but now we do one or the other.
    if (.self$bsetx1) {
      .self$simx1()
    } else {
      .self$simx()
    }
  }
)

# There is no fitting summary function for objects of class Arima.
# So this passes the object through to print, and z$summary() is essentially print(summary(x)).

#' Summary of an object of class Arima
#' @method summary Arima
#' @param object An object of class Arima
#' @param ... Additional parameters
#' @return The original object
#' @export


summary.Arima = function(object, ...) object
