﻿EnableExplicit

CreateDirectory(GetHomeDirectory()+"/.tpfmm")
SetCurrentDirectory(GetHomeDirectory()+"/.tpfmm")

CompilerSelect #PB_Compiler_OS
  CompilerCase #PB_OS_Linux
  CompilerCase #PB_OS_Windows
  CompilerCase #PB_OS_MacOS
CompilerEndSelect

XIncludeFile "module_main.pbi"

main::init()

End
