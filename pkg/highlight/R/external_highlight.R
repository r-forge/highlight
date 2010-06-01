
private <- new.env()

.findExternalHighlight <- function(){
	
	cmd <- "highlight --version"
	tryCatch( {
		system( cmd, intern = TRUE )
		private[["has_highlight"]] <- TRUE
	}, error = function(e){
		private[["has_highlight"]] <- FALSE
	} )
}
