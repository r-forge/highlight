\name{print.function}
\Rdversion{1.1}
\alias{print.function}
\title{
print functions using syntax highlighting and the xterm renderer
}
\description{
This function overrides \code{print.function} from the base package to allow
\code{\link[highlight]{highlight}} to perform syntax highlighting. 
The highlighted syntax is rendered using the xterm renderer.
}
\usage{
print.function(x, useSource = TRUE, detective = getOption("detective"), ...)
}
\arguments{
  \item{x}{
function to print
}
  \item{useSource}{
logical. Should the \samp{source} attribute be used if it exists.
}
  \item{detective}{
	  the detective \code{\link[highlight]{highlight}} should use
}
  \item{\dots}{
Ignored
}
}
\value{
The x argument is returned invisibly
}
\author{
Romain Francois <francoisromain@free.fr>
}
\seealso{
	\code{\link[highlight]{highlight}}
	\code{\link{renderer_xterm}}
}
\examples{
	\dontrun{
		print( print.function )
		
		# auto printing works too
		print.function
	}
}
\keyword{ manip }
