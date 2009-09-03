rscript <- function( package, script, arguments = commandArgs(TRUE), run = TRUE ){
	
	Rscript <- file.path( R.home(), "bin", "Rscript" )
	script  <- system.file( 'exec', script, package = package )
	
	arguments <- if( length( arguments ) == 0 ) "" else paste( arguments, collapse = " " )
	cmd <- sprintf( '"%s" "%s" %s', Rscript, script, arguments )
	
	if( run ){
		system( cmd )
	} else {
		cmd
	}
}

