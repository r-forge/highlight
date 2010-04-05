\name{img}
\alias{img}
\title{
encode a png file as a img data uri
}
\description{
This creates html code to embed a png file into an html document. 
}

\details{
The following graph is embedded in the document using the \code{img} function	
	
\ifelse{html}{ 
	\Sexpr[results=rd, echo=FALSE]{
	 
	library( base64 )
	library( grDevices )
	library( graphics )
	library( stats )
	
	pngfile <- tempfile()
	png( pngfile, width = 600, height = 400 )
	plot( 1:100, rnorm(100), pch = 21, bg = "red", cex = 2 )
	dev.off()
	img( pngfile, Rd = TRUE )
	
	}
}{ (only when rendered in html) }

}

\usage{
img(file, Rd = FALSE, alt = "image" )
}
\arguments{
  \item{file}{png file to translate into a data uri}
  \item{Rd}{if TRUE, extra markup is added to facilitate inclusion of the image in an Rd file}
  \item{alt}{alternate text}
}
\value{
The html code
}
\references{
	Wikipedia entry for data uri \url{http://en.wikipedia.org/wiki/Data_URI_scheme}
}

\author{
Romain Francois <romain@r-enthusiasts.com>
}
\note{
no checking on the file is performed, so it is up to the user to 
make sure the input file is indeed a png file
}

\seealso{
	\link{encode} is used to encode the file
}
\examples{
\dontrun{
pngfile <- tempfile()
png( pngfile, width = 600, height = 600 )
plot( 1:100, rnorm(100), pch = 21, bg = "red", cex = 2 )
dev.off()
img( pngfile )
}
}
\keyword{programming}
