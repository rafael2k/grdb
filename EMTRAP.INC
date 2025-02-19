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
	EXTRN	RegdumpFLAGS : dword
	EXTRN	RegdumpEAX : dword
	EXTRN	RegdumpEBX : dword
	EXTRN	RegdumpECX : dword
	EXTRN	RegdumpEDX : dword
	EXTRN	RegdumpESI : dword
	EXTRN	RegdumpEDI : dword
	EXTRN	RegdumpEBP : dword
	EXTRN	RegdumpESP : dword
	EXTRN	RegdumpEIP : dword
	EXTRN	RegdumpCS : word
	EXTRN	RegdumpES : word
	EXTRN	RegdumpDS : word
	EXTRN	RegdumpSS : word
	EXTRN	RegdumpFS : word
	EXTRN	RegdumpGS : word
	EXTRN	psp : WORD
	EXTRN	_exit : PROC
	EXTRN	reentry : PROC
	EXTRN	grdbname : BYTE
	EXTRN	veclist : word
	EXTRN	stackseg : word
	EXTRN	stackofs : word
	EXTRN 	indos : dword
	EXTRN	entry3 : PROC
	EXTRN	entry1 : PROC
	extrn	entry6 : PROC
	extrn	entry13 : PROC
	extrn   entry14 : PROC
	EXTRN	dosver : word
	EXTRN   realCS : word
	EXTRN	pleaseExit : BYTE
  EXTRN our1b : PROC
  EXTRN their1b : PROC