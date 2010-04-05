\name{decode}
\alias{decode}
\title{
decode a file formatted in Base64
}
\description{
decode a file formatted in Base64
}
\usage{
decode(input, output = tempfile() )
}
\arguments{
  \item{input}{Input file}
  \item{output}{output file}
}
\value{
none. The output file is written
}
\references{
	This is based on the Base64 code available at \url{http://base64.sourceforge.net/}
	
	Base 64 page at wikipedia: \url{http://en.wikipedia.org/wiki/Base64}
}
\author{
Romain Francois, based on code by Bob Trower
}
\seealso{
	\link{encode} for the reversed operation
}
\keyword{programming}

