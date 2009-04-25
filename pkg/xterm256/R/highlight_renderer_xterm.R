
formatter_xterm <- function( tokens, styles, stylesheet = "default", ... ){
	
	rl <- NULL
	xtr <- getStyleFile( stylesheet, "xterm" )
	if( !is.null( xtr ) ){
		rl <- readLines( xtr )	
		rl <- grep( "=", rl, value = TRUE )
		rx <- "^(.*?)=(.*)$"
		values <- sub( rx, "\\2", rl )
		ids <- sub( rx, "\\1", rl )
		ifelse( styles == "", 
			tokens, 
			sprintf( '\033[%s%s\033[0m', values[ match( styles, ids ) ], tokens ) 
		)
	} else{
		tokens
	}
	 
}

translator_xterm <- function( x ){
	x
}

space_xterm <- function( ){
	" "
}

newline_xterm <- function( ){
	"\n" 
}

header_xterm <- function( ){
	"" 
}                     

footer_xterm <- function( document ){
	"\n"
}

renderer_xterm <- function(
	translator = translator_xterm, formatter = formatter_xterm, 
	space = space_xterm, newline = newline_xterm, 
	header = header_xterm, footer = footer_xterm ,  
	... ){
	
	renderer( translator = translator, formatter = formatter, 
		space = space, newline = newline, 
		header = header, footer = footer, 
		... )
}

