\name{renderer_xterm}
\Rdversion{1.1}
\alias{renderer_xterm}
\alias{newline_xterm}
\alias{space_xterm}
\alias{formatter_xterm}
\alias{translator_xterm}

\title{
highlight renderer using xterm 256 escape sequences
}
\description{
	This function creates a renderer suitable for the \samp{renderer}
	argument of the \code{\link[highlight]{highlight}} function
	using \code{\link{style}} to decorate the tokens with 
	background and foreground color.
}
\usage{
renderer_xterm(translator = translator_xterm, 
	formatter = formatter_xterm(stylesheet = stylesheet), 
	space = space_xterm, newline = newline_xterm, 
	header = NULL, footer = NULL, stylesheet = "default", ...)
translator_xterm(x)
formatter_xterm( stylesheet )
newline_xterm()
space_xterm()
}
\arguments{
  \item{translator}{
translator. No translation is performed. The function simply returns
its argument
}
  \item{formatter}{
formatter. This function will decorate the tokens together with the 
styles decided by the detective using the information contained
in the stylesheet
}
  \item{space}{
Function that returns a space character. 
}
  \item{newline}{
Function that returns a new line character.
}
  \item{header}{
Empty header
}
  \item{footer}{
Empty footer
}
  \item{stylesheet}{
The stylesheet to use. This will be parsed by the 
\code{\link[highlight]{css.parser}} function and the information contained 
will be used by the formatter. Only background and foreground colors 
(css settings \samp{color} and \samp{background}) 
are currently honored by the formatter. 
}
  \item{\dots}{
Additional arguments
}
\item{x}{
	input of the translator. Returned as is.
}
}
\value{
	a \samp{renderer} object suitable for the \samp{renderer}
	argument of the \code{\link[highlight]{highlight}} function
}
\author{
Romain Francois <francoisromain@free.fr>
}
\seealso{
The renderer is actually built by the \code{\link[highlight]{renderer}} function.

The \code{\link[highlight]{css.parser}} is used to parse the css stylesheet

The \code{style} function is used to decorate the tokens with 
background and foreground color.

The \code{\link{print.function}} function uses this renderer
to pretty print functions.
}
\examples{
	\dontrun{
		r <- renderer_xterm( )
		highlight( parser.output = parser( text = deparse(jitter) ), 
			renderer = r, detective = simple_detective )
	}
}
\keyword{ manip }

