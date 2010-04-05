\name{encode}
\alias{encode}
\title{
Encode a file in Base64 format
}
\description{
Encode a file in Base64 format
}
\usage{
encode(input, output = tempfile(), linesize = 72L)
}
\arguments{
  \item{input}{input file}
  \item{output}{output file}
  \item{linesize}{number of characters per line in output file}
}
\value{
nothing. used for the side effect of writing the output file
}
\references{
	This is based on the Base64 code available at \url{http://base64.sourceforge.net/}
	
	Base 64 page at wikipedia: \url{http://en.wikipedia.org/wiki/Base64}
}
\author{
Romain Francois, based on code by Bob Trower
}
\seealso{
	\link{decode} for the reversed operation
}

