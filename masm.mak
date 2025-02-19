#    GRDB - debugger for dos with 32-bit extensions
#    Copyright (C) 1997-2006  David Lindauer
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#    (for GNU General public license see file COPYING)
#
#    you may contact the author at:  mailto::camille@bluegrass.net
#
#    or by snail mail at:
#
#    David Lindauer
#    850 Washburn Ave.  Apt #99
#    Louisville, KY 40222
#
#
# This make file contributed by mike stembler
#
# This is the make file when you want to assemble with MASM
# Syntax is NMAKE -f MASM.MAK
# .AUTODEPEND
#               *Local definitions

#
# Define this next to get it to build in an A20 routine for use without
# XMS
#
RAWA20 = -DRAWA20
#
# Define the following to get it to pull out the full screen
# windowing support.  Image may be several K smaller
#
#NOFS = -DNOFS
#

#               *Translator Definitions*
MASM = ML -Dsizeof=size $(RAWA20) $(NOFS) /Zi /Zm /c /Fl
LIB = LIB
LINK = LINK

#               *Implicit Rules*
.asm.obj:
  $(MASM) $?

.c.obj:
  $(CC) -c {$< }

.cpp.obj:
  $(CC) -c {$< }


#               *List Macros*

EXE_dependencies =  \
        asm.obj \
        asmops.obj \
        breaks.obj \
        compare.obj \
        cpuid.obj \
        dis.obj \
        dispatch.obj \
        dos.obj \
        drive.obj \
        dump.obj \
        entry.obj \
        env.obj \
        exec.obj \
        fill.obj \
        fileio.obj \
        fp.obj \
        hbreak.obj \
        help.obj \
        history.obj \
        inout.obj \
        input.obj \
        ints.obj \
        logging.obj \
        loader.obj \
        math.obj \
        memory.obj \
        mmx.obj \
        move.obj \
        mtrap.obj \
        opcodes.obj \
        opcom.obj \
        operands.obj \
        options.obj \
        pci.obj \
        prints.obj \
        regs.obj  \
        rm32.obj \
        search.obj \
        swift.obj \
        symbol.obj \
        window.obj

#               *Explicit Rules*
grdb.exe: $(EXE_dependencies)
        $(LINK) /L /NOE /M:F @<<
                $(EXE_dependencies:  = +^
                )
                grdb.exe
                grdb.map
,
,
<<


link:
        $(LINK) /L /NOE /M:F @<<
                $(EXE_dependencies:  = +^
                )
                grdb.exe
                grdb.map
,
,
<<

clean:
        del *.bak
        del *.obj
        del *.t*

move:
        move *.exe \util\lang