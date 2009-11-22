
formatter_xterm <- function(stylesheet){
	function( tokens, styles, stylesheet = "default", ... ){
		css <- getStyleFile( stylesheet, "css" )
		p   <- css.parser( css )
		dec <- lapply( p, function( declaration ) {
			out <- list( bg = NA, fg = NA )
			if( "color" %in% names(declaration) ){
				out[["fg"]] <- declaration[["color"]]
			}
			if( "background" %in% names(declaration) ){
				out[["bg"]] <- declaration[["bg"]]
			}
			out
		} )
		dec.fg <- as.character( sapply( dec, "[[", "fg" ) )
		names( dec.fg ) <- names( dec) 
		
		dec.bg <- as.character( sapply( dec, "[[", "bg" ) )
		names( dec.bg ) <- names( dec) 
		
		out <- style( tokens, 
			bg = if( !all(is.na(dec.bg) ) ) dec.bg[styles], 
			fg = if( !all(is.na(dec.fg) ) ) dec.fg[styles] )
		out
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

renderer_xterm <- function(
	translator = translator_xterm, 
	formatter = formatter_xterm( stylesheet = stylesheet ), 
	space = space_xterm, newline = newline_xterm, 
	header = NULL, footer = NULL, 
	stylesheet = "default", 
	... ){
	
	renderer( translator = translator, formatter = formatter, 
		space = space, newline = newline, 
		header = header, footer = footer, 
		... )
}

