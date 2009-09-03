\name{rscript}
\Rdversion{1.1}
\alias{rscript}
\title{
Execute an R script located in the exec directory of a package
}
\description{
Execute an R script located in the exec directory of a package
}
\usage{
rscript(package, script, arguments = commandArgs(TRUE), run = TRUE)
}
\arguments{
  \item{package}{package in which the script is contained}
  \item{script}{name of the script, relative to the exec directory of the package}
  \item{arguments}{additional arguments. Typically used at the command line}
  \item{run}{logical. if TRUE the script is run. Otherwise the command is returned}
}
\references{
Writing R extensions
}
\author{
Romain Francois <francoisromain@free.fr>
}
\keyword{ manip }

