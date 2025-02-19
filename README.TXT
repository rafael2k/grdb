1) general info

	GRDB is a real-mode debugger which supports up to the Pentium
	instruction set.

	GRDB is intended as a program development tool.

	GRDB is similar to debug in many ways.  The major departure to the
	basic interface has been in making some of the commands less
	archaic.  Also a variety of status commands have been added to
	help you see what is going on.

	for questions or comments contact the author at:

  camille@bluegrass.net

  The primary web page for GRDB is:

  http://members.tripod.com/~ladsoft/grdb.htm

2) Disclaimer and license

     GRDB - debugger for dos with 32-bit extensions
     Copyright (C) 1997-2006  David Lindauer
 
     This program is free software; you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation; either version 2 of the License, or
     (at your option) any later version.
 
     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.
 
     You should have received a copy of the GNU General Public License
     along with this program; if not, write to the Free Software
     Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 
     (for GNU General public license see file COPYING)
 
     you may contact the author at:  mailto::camille@bluegrass.net

3) Requirements   

GRDB requires at least MSDOS 6.22, a 386 processor, and 640K of memory.
Floating point commands require an FPU, or 486+ processor
MMX commands require an MMX capable pentium class processor

Most commands will work in a DOS shell on windows 96/98/NT/2000/XP.  However
some commands specific to 386 protected mode, such as the flat real support
and 32-bit real mode will not work under windows.  Other commands having to 
do with debugging DPMI programs work with varying success in DOS boxes under
different versions of windows.

4) Features

	GRDB is similar to debug in many ways.  The syntax of the following
	commands departs from the DEBUG syntax:

	h,l,w

	and some of the l & w functionality has been split to new
	commands.  In addition the 'n' command is now used for FPU status; 
	the name of a program is set in the l or w commands if necessary.

	In addition the following features have been added:

	a) software breakpoints

	b) interrupt status screen

	c) configuration options screen

	d) memory (arena) display screen

	e) program information screen

	f) session logging
	
	g) allows loading EXEs without the EXE parsing mechanism

	h) hardware breakpoints

	i) command line history

  j) support for floating point coprocessor

  j) PCI read/write has been updated courtesy of lechee lai
  
  k) MMX instructions and register dump/altering

  l) support for viewing MSRs

5) command line interface

	the command line interface is similar to that of debug.  However,
	some enhancements have been made:

	a) knows the names of all registers and allows you to use them
	   anywhere a number is allowed.  It knows 8, 16, and 32-bit
	   register names...

	b) it knows how to parse string values and convert them to hex.
	   so, a quoted string can be used anywhere a non-address value
	   can be used.  HOWEVER, in many cases strings used as addresses
	   will be truncated to 4 bytes.  Also, some commands
	   (notably fill) will only use the least significant value
	   of the number and will truncate it to one character

	c) commas are always treated like spaces.

	d) CTRL-BREAK is routed to the debugger, and will normally
	   cause the program to halt at its present position as if there
	   were an int 3 in the program stream.  However:

	   if interrupts get disabled you are out of luck.

	   if there is a runaway condition that never returns control to
	   memory belonging to your program you are out of luck

	   if DOS is executing, the break will not happen until the
	   end of the current DOS call.  However it IS (remotely) possible
	   that your break will come in between the int 21h and the
	   time the indos flag gets set, in which case you will break
	   early in the int 21h routine.

	   DOS won't receive a break notification.

	e) you may use up-arrow, and down-arrow to move through previous
	   commands, or F3 to grab the last command you issued.  Old
	   commands will automatically be flushed as needed.  If a new
	   command matches an old command it will not be added to
	   the command list again.  Only primary commands will be logged,
	   for example assembly language statements will not be logged.

  f) you can do math on the command line, for example:

     d di, di+1ff

     is a legal command which dumps 200h bytes starting at di

    it knows how to do math on segment registers as well

  g) pressing <ENTER> after a d,p,t, or u command will repeat the command

  h) on commands that take a start and end address (such as the 'd' command)
     GRDB will accept a start and length instead.  Specify it like this:

     d 200l44  (lower case 'l')

     which dumps 68 bytes starting at address 200

6) Commands

Here is a brief list of commands:

a  [addr]                      - assemble
b  [d][#]                      - Show breakpoint(s)
b  [d][-]#,addr[,r/w/x[,len]]  - set or clear a breakpoint
c  block1, block2, len         - compare memory
cls                            - clear screen
d[bwd] [start [,end]]          - dump memory
e[bwd] start [,list]           - examine memory
f  start,end [,val]            - fill memory
g  [=start] [,break]           - run from start (or cur pos) to break
h  val1 [+-*/] val2            - hex arithmetic
i[bwd]  port                   - read from port
l  [@] [-] [name[ command]]    - read from file
m  start,end,start2            - move memory
n  [s]                         - show fp regs/status
o[bwd]  port,val               - write to port
p  [r][count]                  - step through
q  [s]                         - quit [save options]
r  [reg[:val]]                 - show/modify regs
rf [list of flag values]       - show/modify flag bits
rm                             - show/modify mmx regs
rn [s]                         - show fp regs/status
s  start,end [,list]           - search for a byte pattern
t  [n] [count]                 - step into
u  [start [,end]]              - unassemble
w  [@addr] [name] [,len]       - write to file
y  [pfa [, reg [,val]]]        - read/[write] PCI info
y? bus, dev, func              - get PFA from bus, dev, func
?                              - this help
??                             - help for extended commands
xr drive: addr,start [,len]    - read logical disk sector
xw drive: addr,start [,len]    - write logical disk sector
@  [a] [logfile]               - start/stop logging to a file
?c                             - return info about the CPU
?i                             - view interrupt info
?m [x]                         - view arena tags
?o [+-option]                  - view/set options
?p                             - view program status
?s reg [,end]                  - view MSR
$  [name[=[val]]]              - set, clear, or show a symbol, or show all symbols
$$l [name]                     - load symbol file
$$w [name]                     - save symbol file
$$$ [value]                    - set symbol table size, or show table info
/ instruction                  - execute instruction immediately

Many of the commands are similar to what DEBUG does.  Note that
the ',' character is always optional.  Following is a detailed description 
of each command:

a <CR>
	assemble from CS:IP
	this is quite a bit different from debug.  You may NOT specify
	segments on a line by themselves, but you may put them either
	before the instruction or before the operand.  instructions up to
	the pentium may be assembled.  You can force any of the prefixes
	if you want, or the assembler will figure out what is needed
	based on the addressing mode.

  note that for the assembly commands, the following psuedo directives
  are defined that will allow you to enter data directly as you are 
  assembling:

    db  byte data
    dw  word data
    dd  dword data

  use of these commands will NOT change the default sizing for those
  commands which allow you to switch the sizing between byte word and
  dword.

a addr <CR>
	assemble from address.  This assembler can assemble up to
	pentium instructions, but, it is slightly different from debug.
	First, prefixes may NOT be placed on a line alone, you must
	place them either before the instruction or before a bracketted
	operand.  If you need to force the addrsiz or opsiz prefixes
	they are called 'as' and 'os', but these must be before the
	mnemonic.  Most of the time you won't need this as the assembler
	figures out what prefixes to use based on the operands.
	Second, it will accept either the NASM or the MASM syntax
	for fpregs and sizing.  Third, sizing is optional on things
	like 'mov [5],33', but, you may not like the defaults so put it
	on if in doubt.  Much of the time the assembler will choose
	constant sizing based on the size of the constant if it can, but
	this is not true if not even the size of the operand is specified.
	Fourth, it does NOT know forms of FP instructions that imply
	fwait, for example use the sequence 'fwait fnstsw' if you need
	fstsw.

	assembler known bugs:
	sizing - not strict most of the time.  Entering an invalid
		size will usually result in it using a valid size that
		you don't want.  Sometimes it checks though :)
	setcc instructions don't even check register sizing...

	note: a few ppro instructions have been implemented.  Should be
	everything but the new floating point, which I probably won't
	implement as they are discontinuing the ppro.


b <CR>  
	show active breakpoints.  
	this Does nothing if no breakpoints are active.

b# <CR>  
	where '#" is any number from 0-0F.  
	this Shows the value of that breakpint.

b # , address <CR> 
	where '#' is a hex number from 0 to 0F and
	address is any valid address.  Sets a breakpoint.  At run time
	an 'int 3' will be inserted at the address.  Note that breakpoint
	0 is a special breakpoint used by the 'go' command; it will be
	automatically cleared at the end of the next go/trace/proceed.

b-# <CR>
	clears a breakpoint

b-* <CR>
	clear all breakpoints

bd <CR>
	show all hardware breakpoints

	Note: hardware breakpoints are not available while in a windows
	shell as paging is non-linear.  The program will remind you.

bd# <CR>
	where '#" is any number from 0-3.  
	this Shows the value of that hardware breakpint.

bd# , address <CR> 
	where '#' is a hex number from 0 to 4 and
	address is any valid address.  Sets a hardware breakpoint with
	style 'execution' and length 1.  Hardware breakpoints use the
	386 hardware breakpoint mechanism and do NOT result in modification
	of code or tracing.  I/O breakpoints which were allowed
	beginning with the pentium pro are not supported.

	note: hardware breakpoints stop immediately AFTER the
	instruction which caused the breakpoint activity.  This is in
	contrast to software breakpoints, which stop before.

bd#, address, w <CR>
	sets hardware breakpoint for write memory accesses, with length 1

bd#, address, w, len <CR>
	sets hardware breakpoint for write memory accesses, with length 1,2,4

bd#, address, r <CR>
	sets hardware breakpoint for read/write memory accesses, with length 1
	note that the debugger does NOT allow read-only breakpoints.

bd#, address, r, len <CR>
	sets hardware breakpoint for read/write memory accesses, with length
	1,2,4

bd#, address, x <CR>
	sets hardware breakpoint for execute memory accesses, with length 1

bd#, address, r, 1 <CR>
	sets hardware breakpoint for execute memory accesses, with length 1
	cannot use other lengths with execute-style access trapping

bd-# <CR>
	clear the hardware breakpoint

bd-* <CR>
	clear all hardware breakpoints

c start, end, start2 <CR>
	compare memory.  Like DEBUG version.  you may use segment qualifiers
	on both addresses
	
d <CR>	
  display 80h bytes starting at the current location and using the current
  sizing

d[bwd] <CR>
  display 80h bytes starting at the current location and select sizing as
  byte word or dword

d[bwd] addr <CR> 
  display 80H bytes starting at addr and select sizing as byte word or
  dword
  There must be no space between the command and the size specifier, but
  there must be a space before the first address

d addr,addr <CR>  
  display all the bytes between the two addresses with the current sizing.  
  The second address may NOT be qualified with a segment.

d[bwd] addr,addr <CR>  
  display all the bytes between the two addresses, and select sizing as byte
  word or dword.  The second address may NOT be qualified with a segment.
  There must be no space between the command and the size specifier, but
  there must be a space before the first address

e addr	<CR> 
  start prompting for data, using current sizing.  Note: you CAN 
  quote a character here.

e[bwd] addr  <CR> 
  start prompting for data, and select sizing as byte word or dword.
  There must be no space between the command and the size specifier, but
  there must be a space before the first address

e addr , list of data <CR>
  put the indicated data at the address, using the current sizing

e[bwd] addr , list of data <CR>
  put the indicated data at the address, and select the sizing as byte,
  word, or dword
  There must be no space between the command and the size specifier, but
  there must be a space before the first address

f addr , addr <CR>
	fills all the bytes between the two addresses with 0.
	the second address may NOT be qualified with a segment

f addr , addr , value <CR>
	fills all the bytes between the two addresses with value

f addr, addr, 'text' <CR>
	fills all the bytes between the two addresses with the text

g = addr <CR>
	start executing at address

g addr <CR>
	start executing at current IP, set a temporary breakpoint
	at addr (overwrites breakpoint 0)

g =addr , addr <CR>
	start executing at the first address, set a breakpoint at the
	second address

h val [op] val <CR>
	do some math.  Valid operators are : +-*/%.  If no operator
	is given, it will act like debug.

i port <CR>
  show the (byte) value at the port, using the current sizing
  There must be no space between the command and the size specifier, but
  there must be a space before the port number

i[bwd] port <CR>
  show the value of a port, selecting the sizing as byte, word, or dword.
  There must be no space between the command and the size specifier, but
  there must be a space before the port number

l filename command <CR>
  load a file, setting its command line.  The command is optional.  This
  command WILL check the file to see if it is an EXE file no matter
  what the extension is and load it accordingly if so.

  This command is not available in DPMI mode.

l @ filename <CR>
	load an EXE file without using the normal EXE load mechanism
	(e.g. as a COM file).  Note, you CANNOT run EXEs that are loaded
	this way.

  This command is not available in DPMI mode.

l - <CR>
	unload file

  This command is not available in DPMI mode.

l <CR>
	reload last file

  This command is not available in DPMI mode.

m start,end,start2 <CR>
	move memory from start to start2.  Both start and start2
	may be qualified with segment values.

n <CR>
	show fp registers.  The TOS register will have a star next to
	it.  Note: if you have a 386 with no coprocessor you will get an
	error message.  Also, my version of TASM puts an FWAIT in front
	of the frstor statement used in this command and the next.  This
	could cause problems if you've got exceptions vectored through
	an interrupt and show fp status while an exception is active.
	Older versions of TASM apparently don't do this.

ns <CR>
	show fp status.  Shows masked exceptions, active exceptions,
	rounding/precision selections, and status of the C? flags.  Note:
	if you have a 386 with no coprocessor you will get an error message.

n #, val <CR>
	set the value in an FP register.  This command will NOT push
	stuff on the FP stack, if a register is tagged empty you are out
	of luck.  If you want to enter infinity that is +inf or -inf,
	likewise a NaN is +nan or -nan (although the fpu ignores the
	sign on a nan you can still put it in).  Only non-signaling NaNs
	are supported at this time.  Yes, you can enter -0 if you want.

o port, val <CR>
  output a value to a port, using the current sizing
  There must be no space between the command and the size specifier, but
  there must be a space before the port number

o[bwd] port, val <CR>
  output a value to a port, selecting the sizing as byte word or dword
  There must be no space between the command and the size specifier, but
  there must be a space before the port number

p <CR>
	step over subroutines, string instructions, int calls.  For
	loop instructions, it runs until the loop falls through.  This is
	a DESTRUCTIVE instruction, it modifies the code stream temporarily
	if a simple trace won't do.

p count <CR>
	step over subroutines, execute <count> instructions before stopping
	pressing any key during the counted proceed operation will stop
	the program.

pr <CR>
	proceed until the end of this subroutine.  traces until it
	hits a ret or iret, nesting is maintained.  Calls and interrupts
	and repeat string instructions run at full speed.  Note that
	when it stops you will be after the subroutine call instruction.

	warning: I am not sure what happens with recursion.  Also in
	(vanishingly) rare instances involving run-time stack switches
	this will halt with a garbled CS:IP.

q <CR>
	exit debugger

qs <CR>
        exit debugger and write options file

r <CR>
	show registers

r reg <CR>
	prompt for a new value for reg

r reg , value <CR>
	stuff a new value in reg

rf <CR>
        show flag bits and allow modification

rf flag bits <CR>

        modify flag bits

rm <CR>
        show MMX registers

rn <CR>
	show fp registers.  The TOS register will have a star next to
	it.  Note: if you have a 386 with no coprocessor you will get an
	error message.  Also, my version of TASM puts an FWAIT in front
	of the frstor statement used in this command and the next.  This
	could cause problems if you've got exceptions vectored through
	an interrupt and show fp status while an exception is active.
	Older versions of TASM apparently don't do this.

rns <CR>
	show fp status.  Shows masked exceptions, active exceptions,
	rounding/precision selections, and status of the C? flags.  Note:
	if you have a 386 with no coprocessor you will get an error message.

rn #, val <CR>
	set the value in an FP register.  This command will NOT push
	stuff on the FP stack, if a register is tagged empty you are out
	of luck.  If you want to enter infinity that is +inf or -inf,
	likewise a NaN is +nan or -nan (although the fpu ignores the
	sign on a nan you can still put it in).  Only non-signaling NaNs
	are supported at this time.  Yes, you can enter -0 if you want.

s addr , addr , list <CR>
	search.  List may be any combination of quoted strings and hex
	values.  Note: you MAY use a segment value in the second
	argument.  The segment of the result will be adjusted any time
	the offset of the first argument is greater than 8000h.

t <CR>
	step into instruction

t count <CR>
	single step for count instructions
	pressing any key during the counted single step operation will stop
	the program.

u  <CR>
	disassemble from current location.  Location gets set to CS:IP
	each time an R command or trace/go is executed.

u addr <CR>
	dissassemble from address

u addr, addr <CR>
	disassemble code between the two addresses.  Second address may
	NOT be qualified with a segment

w <CR>
	write file to disk.  If no file is loaded or loaded file
	is an EXE file loaded in EXE format you will get an error.

  This command is not available in DPMI mode.

w name <CR>
	write the file, giving it a new name.  This will allow you to
	resave an exe image, but bear in mind if you loaded it as an
	exe file you don't get a header and fixups have been performed.

  This command is not available in DPMI mode.

w name len <CR>
	write the file, giving it both a name and a length

  This command is not available in DPMI mode.

w ,len <CR>
	write the file, with a specific length.  Resets the
	file length

  This command is not available in DPMI mode.

w @addr name len <CR>
	write a file from address of length len with name name.  Note that if
	an address is given you MUST give a name and length

  This command is not available in DPMI mode.

xr drive: addr, sector <CR>
	read one (logical) sector from the disk.
	Note that DRIVE is a letter from a to z.

  This command is not available in DPMI mode.

xr drive: addr, sector, len <CR>
	read multiple (logical) sector from the disk.

  This command is not available in DPMI mode.
	
xw drive: addr, sector <CR>
	write one (logical) sector from the disk.
	Note that DRIVE is a letter from a to z.

  This command is not available in DPMI mode.

xw drive: addr, sector, len <CR>
	write multiple (logical) sector from the disk.

  This command is not available in DPMI mode.

y <CR>
        show all PCI devices

	Note: the 'y' commands may not work in a DOS shell under windows.

y pfa <CR>
        show data space for this pci device

y pfa, reg <CR>
	PCI- read a value from this register of this PFA and display it

y pfa, reg, val <CR>
	PCI- write a value to this register of this PFA

y? bus, dev, func <CR>
	PCI- calculate the PFA address from the bus, device, and function
	given and display it.  No PCI access is done.

@ filename <CR>
	start logging to a file.  ONLY the debug session is logged;
	not the program output.

@a filename <CR>
	start logging; append instead of truncating.  there can be no
	space before the 'a' or it will be treated as the file name.

@ <CR>
	end logging

? <CR> 
        displays help

?c <CR>
        displays results of CPUID information for pentium-class processors
        note that CPUID does work on some 486-class processors, but GRDB
        will not process this command on those processors.

?g <CR> 
        displays GNU warranty information

?gr <CR> 
        displays general terms of GNU license

?i <CR>
	shows interrupt information.  All interrupts hooked since the
	debugger has been invoked are shown, along with PIC information.
	If an interrupt has a '*' it is currently reserved by the
	debugger and the contents will be lost on the next go/trace/proceed.
	
	PIC information shows the PIC mask registers, and in parenthesis
	the original values of the PIC mask registers and the current value
	of the interrupt request register

	for example:

	02 : CCE4:0000
	03*: 0070:0400

	PIC 0 mask: A8 (A8,00)
	PIC 1 mask: 89 (89,00)

  This command is not available in DPMI mode.

?m <CR>
	shows the arena entry headers belonging to the program.
	also shows the address of the top of the program memory
	(normally 0a000h).  Values are in paragraphs.

	For example:
	Top of memory: 9FFF

	Address: 262E  Owner: Q(2659)          Size: 0029
	Address: 2658  Owner: Q(2659)          Size: 79A6

	the number in parenthesis is the PSP of the owner.  The name will
	be expanded to stars if no file is loaded.

  This command is not available in DPMI mode.

?mx <CR>
	shows all arena headers in the chain

  This command is not available in DPMI mode.

?o <CR>
	show options.  See the next section


?o +opt <CR>
	set an option

?o -opt <CR>
	clear an option

?p <CR>
	status about program size, PSP and environment location,
	some EXE characteristics, etc.

	For example:

	Dos version: 07.00
	Mode: real
	CPU type: Pentium Pro

	Program:   grdb.exe
	Arguments:  grdb.exe
	File length: 518A
	CS:IP = 266E:1AC0
	SS:SP = 2B87:0800
	minalloc: 0081 maxalloc: FFFF
	relocs: 0008

	Psp at 265E with length 79A1
	Environment at 2633 with 0289 bytes used of 02A0

?s reg [,end> <CR>

    view the 8 bytes of MSR reg.  If the optional parameter 'end' is specified
    view the registers from reg to end.  Note: this command is only available in
    real mode, it won't work in a V86 shell or when GRDB is hosted by a DPMI
    system

/ instruction <CR>

  assembles and immediately executes an instruction, without having
  to put it in memory explicitly.  Does NOT put it at the current
  assemble address.

  Note: CS and IP are not available during execution of such instructions, 
  for example:
   
  /mov ax,cs:[44] 

  will not work properly

$ <CR>

  shows all symbols in the symbol table

$ name <CR>

  shows symbol 'name'

$ name = <CR>

  clears symbol 'name'

$ name = seg:off <CR>

  set symbol 'name' to the segment/offset value

$$l <CR>
  reload the current symbol file

$$l filename <cr>

  set the symbol file name to 'filename' then load it

$$w <CR>

  save the current symbol file

$$w filename <CR>

  save the current symbol file with a new name

$$$ <CR>

  shows symbol table information, such as size of table and number of
  bytes used

$$$ # <CR>

  sets the symbol table to the specified size, in KBytes.  # must be a number
  between 0 and 64.  A value of zero reserves zero memory for the symbol
  table

  This command is not available in DPMI mode.

7) Options

Available options are as follows:

WR - wide registers            disabled
FR - flat real commands        disabled
32 - enable 386+ instructions  enabled
ZR - divide by zero trap       enabled
BK - ctrl-break trap           enabled
NV - native video              disabled
FI - flat real autoinit	       enabled
F0 - flat from zero            disabled
SO - signed immediates	       disabled
HI - history enable	           enabled
MD - MSDOS I/O	               disabled
DD - 32-bit default addressing disabled
SK - stop display on keypress  disabled
DM - Dual Monitor mode         disabled
FS - full screen mode          disabled
SI - case insensitive symbols  disabled
SC - syntax coloring           enabled
HB - hardware breakpoint enable enabled
AN - ansi escape sequences     disabled

To set an option, type ?O followed by its two-character option name.
For example:

?o WR <CR>
	turns on wide registers

?o +WR -32 <CR>
	turns on wide registers and turns off 32-bit instructions.

Options are maintained in a file called 'grdb.opt'.  If the file exists in
the current directory it is read when GRDB starts.  It will not be written
back to the disk unless the 's' parameter of the 'q' command is used.

If grdb.opt does not exist in the current directory, GRDB will attempt to find
it in the directory it executes from.  IF it does, it will load it from there.
This is useful for setting a global default options file.  Note that GRDB
will not attempt to write to the global options file unless you have actually 
changed to the directory GRDB is executed from.

Here are the meanings for the options:

WR: normally the 'r' command will show the 16-bit registers.  Setting
this option will cause it to show the full 32-bit value for each
register.

FR: addresses are normally truncated at 0FFFFH to avoid protection
faults.  Setting this option allows commands to utilize the full
32-bit address range, which can be useful in debugging flat real mode
programs.

32: the debugger normally interprets all instructions up through
the Pentium when showing disassemblies.  Resetting this option will force
it to quit recognizing instructions for any processor above the 80186.

ZR: This debugger traps divide by zero instead of exiting you to DOS.
If you want it to NOT trap divide by zero, for example you have your own
handler... reset this option.

BK: This debugger intercepts the ctrl-break trap and halts the
program (assuming interrupts are enabled and it isn't totally
runaway).  Use this option to disable the handling, e.g. you
want to use your own ctrl-break handler.

NV: in the 'dump' display, the debugger will use native video translations
for most characters in the ascii display (characters that are translated
by video function 0eh can not be displayed natively).  If you want to
see only characters in the ASCII character set, turn this option off.

FI: no function unless the FR option is enabled.  If both the FR and FI
options are enabled, the debugger will transition the FS register
into flat real mode in preparation for flat real commands, otherwise
if just the FR option is set it is up to your program to make the
transition into flat real mode.

F0: no function unless the FR option is enabled.  If both F0 and FI
are enabled then the assembler will default memory commands from
physical address zero rather than from the default data segment.

SO: signed immediates.  Alters the display of the U command to display
signed byte values as 8 bit signed values instead of as 8 bit unsigned

HI: history enable.  When this option is on command line history is
enabled.  When this option is off command line history is disabled.
Turning this off will save about 1024 bytes of memory if you need it.

MD: msdos I/O enable.  Enable this option if you want to use input
redirection to send a script to GRDB

DD: 32-bit addressing. Enable this option if you want the sense of the
ADRSIZE and OPSIZE prefixes swapped (e.g. to assume a 32 bit seg)

SK: stop display on keypress.  When set, a keypress will interrupt
long DISASSEMBLY, DUMP, and counted proceed and trace functions
and make them stop prematurely

DM: Dual Monitor mode. Requires driver by Lawrence E. Boothby from
www.ASM32.com (see his "Shareware"). The driver must be resident
before starting GRDB.EXE or GRDB.EXE will disable feature for the
current session. Dual Monitor mode displays the debugger on the
secondary PCI video adapter while the program being debugged displays
on the primary AGP adapter. This makes debugging graphic mode
programs possible. DM and MD modes are mutually exclusive and
enabling one will automatically disable the other. FS mode may be
used with DM mode - in this case the F5, flip page, key is disabled
because you can already see both screens. Dual monitor mode allows
you to trace into MSDOS, the System Bios, and even the AGP video
adapter shadow rom because it is entirely independent of these.

FS: Full screen mode.  When set the full screen mode will be enabled.
The full-screen mode is not yet fully supported, it is included for
preview purposes only. The F5 function key flips the screen between
the debugger and the program output (when Dual Monitor mode disabled).

SI: Symbols Insensitive to Case.  When having a symbol name evaluated
(e.g. by typing it as an argument to a command), setting this option will
allow the symbol name to be matched regardless of case.  Otherwise the
symbol must be typed in the proper case.

SC: Syntax Coloring.  When this option is on, the output from various
commands will be colored.  It will default to the normal color when this
option is off.

HB: Hardware break point enable.  A global enable/disable for the hardware
breakpoint commands.

AN: Ansi escape sequence enable.  Uses ansi escape sequences for cursor movement
and display.  Useful when using GRDB over a serial port.



8) guidelines
	a) the debugger uses two interrupt tables; one for itself and one for
	    the program being debugged.  Most commands commands will transparently
		view or modify the program's interrupt table; exceptions are U and A
		which will not work properly in the interrupt table.  Also, setting
		breakpoints in the interrupt table will not work.

		Another issue is that when certain commands run, the program interrupt
		table is switched in for the duration of the command.  This is somewhat
		problematic if the command uses an interrupt that has been replaced, for
		example if int 25 or int 26 is replaced then the drive command is used,
		there will be problems.

		The following interrupts are ALWAYS off-limits:

		01 - debug trap
		03 - breakpoint trap
		20 - DOS exit routine

	   The following interrupts are off-limits unless you set the
	   appropriate option off:

		00 - divide by zero trap
		1b - breakpoint trap

	   In addition, hooking int 21h is problematic since the debugger
	   needs to hook it for a variety of reasons.  if you HAVE to
	   hook it, do NOT write directly to the interrupt table but instead
	   do a DOS call (function 25h,35h) to keep the debugger in sync
	   with you.

	   The debugger does not care what you do with other interrupt
	   vectors

	b) Unless you have logging enabled, the program can be configured to not
		use DOS for I/O with ?o -md.  However it DOES need to go resetting 
		the PSP a lot; so I'm not sure how safe it is to step through DOS.

	c) The debugger maintains a proper program context even when no
	   program is loaded.

	d) int 20h from the wrong CS WILL work, but you will get a
	   warning message.  Note this will cause a crash if the debugger
	   isn't running!

    e) CS is not available when using the '/' command

	f) the syntax coloring may not work correctly if ANSI.SYS is loaded.
		if this is the case, then use ?o-md to make I/O go through the bios.

9) FLAT REAL SUPPORT

	There are two options dealing with flat real mode.  The first
	is the FR option.  When enabled, this causes numbers to be
	interpreted as 32-bit rather than 16-bit when possible (note
	that the assembler will always allow 32-bit numbers).

	The second is the FI option, when this is enabled in conjunction
	with the FR option the debugger will transition the FS register
	into flat real mode and use XMS to enable the A20 line.  You should
	disable the FI option to test the flat real mode initialize routines
	in your own program.

	The FI option is disabled if you are in a windows or EMM386 shell.
  You probably shouldn't use the FR option when in windows either,
	it will give incorrect results and maybe a general protection
	trap.

	The following commands work with 32-bit addresses:

  c,d,e,f,m,s

	Disassemblies do NOT work with 32-bit addresses as this is a
	real-mode debugger, also other commands are not certified to
	work with 32-bit addresses at this time.

  This version of GRDB will detect RM32 code segments and respond
  appropriately; e.g. you can debug 32 bit real mode code with the
  debugger.  However to do this, you need to make sure that whatever 
  interrupt table you are using uses the int 1 and int 3 vectors
  GRDB places in the table at offset zero.  That is if you make a thunk
  table, do NOT thunk these interrupts but use the original values as
  provided by GRDB to allow the debugger to work.

	the ?p command has been updated to tell which mode GRDB is in.

10) DPMI Support

	the current version of GRDB supports debugging sixteen and 32-bit
	DPMI programs.  A DPMI host must be loaded prior to starting GRDB.
	GRDB will hook the DPMI entry point and perform initialization such
	as hooking various interrupts and exceptions prior to transfering control
	to the DPMI program.

	The DPMI support works in DOS and on winXP, however it cannot work in
	win9x.

	In DPMI mode, GRDB performs similarly to real mode.  However, some commands
	that are specific to real mode are disabled.  Also in general, hardware
	breakpoint support will be disabled.  

	If a command is issued in GRDB which causes a segment fault (e.g. invalid
	address) GRDB will display an invalid memory access error and return to the
	prompt.  Otherwise if a fault occurs while the program is running, GRDB
	will stop with a normal trace output indicating where the fault occurred.

	Symbol table support does work in DPMI mode, however, the symbol table must
	be allocated ($$$) while in real mode and before DPMI mode is entered.  An
	attempt to allocate a symbol table while in DPMI mode will fail because the
	allocation uses DOS memory management.

	When issuing a command that uses a memory address, the selector '0' may be
	used to indicate you want to look at the linear address space.  For example:

	d 0:400  

	looks at the bios data area.

	When in DPMI/32 mode, GRDB will automatically work as if the associated 
	options for disassembling code and evaluating memory addresses in 32-bit
	mode are turned on.

	In DPMI mode, GRDB is unable to set/reset the PSP at breakpoints.  GRDB
	commands that need the PSP will use the program context instead of the GRDB
	context while in DPMI mode.  In general this affects file i/o operations.

  DPMI support was tested with Borland's 32RTM.EXE (bc4.5) and with Japheth's
  HXDOS.


11) Symbol table

  GRDB now supports a symbol table.  You can build it by hand, or use
  an external tool to generate it from the linker output.  Before using it
  you have to do $$$<size>  to set a size for it, from 1-64K.  The size
  will be saved in the GRDB.OPT file if you create one.

	$$$<size> does not work once GRDB has entered DPMI mode.

  To create, load, or save the symbol file use the appropriate $-sequence
  command.  You can also view the current symbols directly from GRDB.

  External tools are available on my web site for creating the symbol
  file automatically.

  On the site you will find a MKSYM program which will take the map file
  from common linkers and generate a symbol table.  Note that the map file
  must be generated in such a way that it will enumerate PUBLIC definitions
  for this to work.  The only values that will appear in the symbol table
  are publicly-defined variables.

  I'm also making available a version of VALX which will directly generate
  a symbol table.  VALX is similar to the microsoft linker but in addition
  to outputting plain dos programs it will output other formats, such as LE
  and PE files.

  The symbol table contents can be used on the commandline anywhere an
  address can be used; the offset values (but not segment values) may also
  be used as arguments to instructions to be assembled.  The disassembler will
  as much as possible resolve addresses to their symbolic value; but note
  that to do this it often uses the actual values of the segment registers
  so if a segment register isn't set right the output won't look right.

  The symbol table is saved in relocatable fashion as much as possible;
  in practice the only values that will be relocatable on save from GRDB
  are values that are in the primary memory block which makes up the 
  program.  Both MKSYM and VALX will create relocatable symbol files.

12) Serial port support

  GRDB will now work with a bios which has a serial console, accessed from a VT100
  or from a terminal emulator such as hyperterm.  It works with VT100 series
  escape sequences.

  Two options need to be changed from the default to enable the serial port
  support.  First, native video needs to be turned off (?o-nv).  Then, ansi
  escape sequences need to be turned on (?o+an).  These settings may be saved
  to disk and automatically loaded in later sessions with the 'qs' command.

13) future changes

The following changes may be made at a later date:

a) OPTIONS file renamed to fit the program being done, breakpoints
   will be logged in the options file

c) loading of HEX files
