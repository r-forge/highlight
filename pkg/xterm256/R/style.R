
#' wraps the text given by x in the background and foreground color
#' provided
#' 
#' @param x text to style
#' @param fg foreground color
#' @param bg backgorund color
style <- function( x, fg = NULL, bg = NULL, check.xterm = TRUE ){

	if( check.xterm && Sys.getenv( "TERM" ) != "xterm" ) return(x)
	if( is.null( fg ) && is.null(bg ) ) return(x)
	
	fg. <- xtermColor( fg, length(x) )
	bg. <- xtermColor( bg, length(x) )
	
	out <- character( length( x ) )
	if( !is.null( fg ) ){
		out <- ifelse( is.na(fg.), "", sprintf( "\x1b[38;5;%dm", fg.) )
	} 
	if( !is.null( bg ) ){
		out <- paste( 
			ifelse( is.na(bg.), "", sprintf( "\x1b[48;5;%dm", bg. ) ), 
			out, sep = "" )
	}
	out <- paste( out, x, "\x1b[0m", sep = "" )
	out
}

xtermColor.NULL <- function( color, n ){
	rep( NA, length.out = n )
}

xtermColor <- function( color, n ){
	UseMethod( "xtermColor" )
}

xtermColor.numeric <- function( color, n ){
	xtermColor.integer( as.integer(color), n )
}

xtermColor.integer <- function( color, n ){
	if( !all( is.na(color) | ( color >= 0 & color <256)  ) ){
		stop( gettext("all colors should be NA or between 0 and 255") )
	}
	rep( color, length.out = n )
}

closest <- function( colors ){
	UseMethod( "closest" )
}
closest.character <- function( colors ){
	
	hex <- grepl( "^#", colors ) 
	res <- integer( length(colors ) )
	if( any(hex, na.rm = TRUE) ){
		res[!is.na(colors) & hex]  <- closest.matrix( t( col2rgb( colors[hex] ) ) )
	}
	if( any( !hex, na.rm = T) ){
		res[!is.na(colors) & !hex] <- closestStandardColors( colors[!hex] )
	}
	res[is.na(colors)] <- NA
	res
}


makeClosestMatrix <- function( ){
	
	rgb.levels <- 0:5 *40 + 55
	xterm256.rgb  <- rev( expand.grid( 
		blue = rgb.levels, green = rgb.levels, red = rgb.levels ) )
	rownames(xterm256.rgb) <- 16:231
	
	gray.levels <- (0:23)*10 + 8
	xterm256.gray <- data.frame( 
		red = gray.levels, green = gray.levels, blue = gray.levels )
	rownames(xterm256.gray) <- 232 + 0:23
	
	xterm256.all <- rbind( xterm256.rgb, xterm256.gray )
	        
	function( colors ){
		
		all.colors <- rbind( xterm256.all, colors )
		distance <- as.matrix( dist( all.colors ) )[ 
			1:nrow(xterm256.all), 
			nrow(xterm256.all) + 1:nrow(colors), drop = FALSE ]

		mapping <- as.integer( rownames( distance)[
			apply( distance, 2, which.min )
			] )
		names( mapping ) <- rownames(colors)	
		mapping
	}
	
}
closest.matrix <- makeClosestMatrix()
closest.data.frame <- function( colors ){
	closest( as.matrix( colors ) )
}

makeClosestStandardColors <- function(){

	R.colornames <- colors()
	R.colors <- t( col2rgb( R.colornames ) )
	rownames( R.colors ) <- R.colornames
	standardColors.mapping <- closest.matrix( R.colors )
	
	function( colors ){ 
		standardColors.mapping[ colors ]
	}
}
closestStandardColors <- makeClosestStandardColors( )

xtermColor.character <- function( color, n ){
	xtermColor( closest( color ), n )
}

showColors <- function( cols = colors() ){
	width <- max( nchar( cols ) ) + 2
	n <- floor( getOption( "width" ) / width)
	txt <- style( sprintf( sprintf( "%%-%ds", width ), cols ), fg = cols )
	txt <- suppressWarnings( apply( matrix( txt, ncol = n, byrow = TRUE), 1, paste, collapse = " " ) )
	cat( txt, sep ="\n" )
}

