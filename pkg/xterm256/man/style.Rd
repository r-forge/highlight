\name{style}
\encoding{utf-8}
\Rdversion{1.1}
\alias{style}
\title{
	Applies foreground and background color to text
}
\description{
	The function wraps the text x in the appropriate xterm 256 escape
	sequences to add backgorund and foreground color
}
\usage{
style(x, fg = NULL, bg = NULL)
}
\arguments{
  \item{x}{
text to style
}
  \item{fg}{
foreground color
}
  \item{bg}{
background color
}
}
\value{
	The text \code{x} possibly wrapped in escape sequences
}
\references{
	\url{http://frexx.de/xterm-256-notes/}
}
\author{
Romain Francois <francoisromain@free.fr>
}

\examples{
	\dontrun{
		text <- c( "liberté", "égalité", "fraternité" )
		bg   <- c("blue", "white", "red" )
		line <- paste( 
			rep( " ", length.out = sum( nchar( text ) ) + 2 ), collapse = "")
		{
				cat( style( line, bg = "gray95" ), "\n" )
				cat( style( text, bg = bg), "\n", sep = " " )
				cat( style( line, bg = "gray95" ), "\n" )
		}
		
		cat( style( "hex", bg = "#cccccc", fg = "#0000ff" ), 
			"and", 
			style( "rgb", bg = rgb( 1, 0, 0), fg = rgb(1,1,1) ), 
			"are also supported", 
			"\n" ) 
		
		if( require( pixmap ) ){
			 rlogo <- read.pnm( system.file( "rlogo.pnm", package= "xterm256") )
			 rlogo.rgb <- data.frame( 
			 	red = as.integer(rlogo@red * 255), 
				green =  as.integer(rlogo@green * 255), 
				blue =  as.integer(rlogo@blue * 255) )	
			 cl <- closest(rlogo.rgb)
			 rlogo.text <- style( rep( " ", length(cl)), bg = cl )
			 dim( rlogo.text ) <- c( 38, 50 )
			 cat( apply( rlogo, 1, paste, collapse = ""), sep ="\n" )
			 
		}
		
		
	}
}

\keyword{ manip }

