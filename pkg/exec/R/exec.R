rscript <- function( package, script, arguments = commandArgs(TRUE), run = TRUE, dir = "exec" ){
	
	Rscript <- file.path( R.home(), "bin", "Rscript" )
	script  <- system.file( dir, script, package = package )
	if( !file.exists( script ) ){
		stop( sprintf( "script '%s' does not exist", script) )
	}
	
	arguments <- if( length( arguments ) == 0 ) "" else paste( arguments, collapse = " " )
	cmd <- sprintf( '"%s" "%s" %s', Rscript, script, arguments )
	
	if( run ){
		system( cmd )
	} else {
		cmd
	}
}

