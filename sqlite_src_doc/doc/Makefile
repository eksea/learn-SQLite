#!/usr/make
#
# Makefile for SQLite Documentation
#

#### The toplevel directory of the documentation source.
#
DOC = .

#### The toplevel directory of the program source code.
#
SRC = ../sqlite

#### The directory in which has been run "make sqlite3.c" for the
#    SQLite source code.  The documentation generator scripts look
#    for files "sqlite3.h" and "tclsqlite3.c" in this directory.
#
BLD = ../sqlite

#### The toplevel directory of the TH3 test harness sources
#    Leave blank if TH3 is not available.
#
TH3 =

#### The toplevel directory of the SQLLogicTest (SLT) test
#    harness sources.  Leave blank if SLT is not available.
#
SLT =

#### A C-compiler for building utility programs to run locally
#
CC = gcc -g -Wall

#### Extra C-compiler flags needed to compile TCLSH
#
TCLINC =
TCLFLAGS = -ldl -lm -lpthread -ltcl -lz

#### Extra C-compiler flags needed to compile a TCL extension that
#    is stubs enabled.
#
TCLSTUBFLAGS = -ldl -lm -lpthread -ltclstub -lz

#### Which "awk" program provides nawk compatibilty
#
# NAWK = nawk
NAWK = awk

# You should not have to change anything below this line
###############################################################################
include $(DOC)/main.mk
