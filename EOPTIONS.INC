;    GRDB - debugger for dos with 32-bit extensions
;    Copyright (C) 1997-2006  David Lindauer
;
;    This program is free software; you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation; either version 2 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program; if not, write to the Free Software
;    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
;
;    (for GNU General public license see file COPYING)
;
;    you may contact the author at:  mailto::camille@bluegrass.net
; 
;    or by snail mail at:
;
;    David Lindauer
;    850 Washburn Ave.  Apt #99
;    Louisville, KY 40222
;
	EXTRN	optdword : byte
	EXTRN	optdwordcommand : byte
	EXTRN	doopt : PROC
	EXTRN	optdiv0 : byte
	EXTRN	optpure : byte
  EXTRN optflat0 : byte
  EXTRN optsignedimm : byte
	EXTRN	ReadOptions : PROC
	EXTRN	WriteOptions : PROC
	EXTRN	opthist : byte
	EXTRN	Disassemble32Bit : byte
  EXTRN optdosio : byte
  EXTRN optass32 : byte
  EXTRN optflatinit : byte
  EXTRN optsymname : byte
  EXTRN writeopts : byte
  EXTRN optcisym : byte
  EXTRN optSyntaxColoring : byte
  EXTRN bit32Address : PROC
  EXTRN opthbreak : byte
  EXTRN optansi : byte
  EXTRN optdm : byte