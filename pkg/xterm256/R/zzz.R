.onAttach <- function( libname, pkgname ){
	old.op <- options( width = 100 )
	rlogo.text <- read.table( 
		system.file( "rlogo.txt", package= "xterm256"), 
		header = F )
	cat( apply( rlogo.text[,rep(1:ncol(rlogo.text), each = 2)], 1, paste, collapse = ""), sep ="\n" )	
	options( old.op )	
}
