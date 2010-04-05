decode <- function(input, output = tempfile() ){
	invisible( .Call( "decode_", input, output, PACKAGE = "base64" ) )
}

encode <- function(input, output = tempfile() , linesize = 72L ){
	invisible( .Call( "encode_", input, output, as.integer(linesize), PACKAGE = "base64" ) )
}

img <- function( file, Rd = FALSE, alt = "image" ){
	tf <- tempfile()
	on.exit( unlink(tf) )
	encode( file, tf )
	sprintf( '%s<img src="data:image/png;base64,\n%s" alt="%s" />%s', 
		if( Rd ) "\\out{" else "", 
		paste( readLines( tf) , collapse = "\n" ), 
		alt,
		if( Rd ) "}" else ""
	)	
}
