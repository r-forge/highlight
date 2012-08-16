/* Copyright (c) 2001 Bob Trower, Trantor Standard Systems Inc.
 * Copyright (c) 2010-2011 Romain Francois
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, a copy is available at
 *  http://www.r-project.org/Licenses/
 */

#ifndef BASE64__BASE64_H
#define BASE64__BASE64_H

#include <R.h> 
#include <Rinternals.h> 

#include <stdio.h>
#include <stdlib.h>

/*
** returnable errors
**
** Error codes returned to the operating system.
**
*/
#define B64_SYNTAX_ERROR        1
#define B64_FILE_ERROR          2
#define B64_FILE_IO_ERROR       3
#define B64_ERROR_OUT_CLOSE     4
#define B64_LINE_SIZE_TO_MIN    5

#define B64_DEF_LINE_SIZE   72                                                         
#define B64_MIN_LINE_SIZE    4

#define THIS_OPT(ac, av) (ac > 1 ? av[1][0] == '-' ? av[1][1] : 0 : 0)

#define B64_MAX_MESSAGES 6

SEXP encode_(SEXP input, SEXP output, SEXP line_size) ;
SEXP decode_(SEXP input, SEXP output) ;


#endif                                                                         
