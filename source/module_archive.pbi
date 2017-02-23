﻿XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"

DeclareModule archive
  EnableExplicit
  
  Declare extract(archive$, directory$)
  Declare pack(archive$, directory$)
  
EndDeclareModule


Module archive
  
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      ; important: create 7z.exe and 7z.dll files
      DataSection
        data7zExe:
          IncludeBinary "7z/7z.exe"
        data7zExeEnd:
        
        data7zDll:
          IncludeBinary "7z/7z.dll"
        data7zDllEnd:
        
        data7zLic:
          IncludeBinary "7z/7z License.txt"
        data7zLicEnd:
      EndDataSection
      
      CreateDirectory("7z")
      misc::extractBinary("7z/7z.exe",          ?data7zExe, ?data7zExeEnd - ?data7zExe, #False)
      misc::extractBinary("7z/7z.dll",          ?data7zDll, ?data7zDllEnd - ?data7zDll, #False)
      misc::extractBinary("7z/7z License.txt",  ?data7zLic, ?data7zLicEnd - ?data7zLic, #False)
    CompilerDefault
      CompilerError "No unpacker defined for this OS"
  CompilerEndSelect
  
  
  Procedure extract(archive$, directory$)
    ;clean dir before extract?
    Protected program$, parameter$
    Protected program, exit
    
    If FileSize(archive$) <= 0
      debugger::add("archive::extract() - Error: Cannot find archive {"+archive$+"}")
      ProcedureReturn #False
    EndIf
    
    misc::CreateDirectoryAll(directory$)
    If FileSize(directory$) <> -2
      debugger::add("archive::extract() - Error: Cannot create target directory {"+directory$+"}")
      ProcedureReturn #False
    EndIf
    
    ; define program
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        program$ = "7z/7z.exe"
        parameter$ = "x "+#DQUOTE$+archive$+#DQUOTE$+" -o"+#DQUOTE$+directory$+#DQUOTE$
    CompilerEndSelect
    
    ; start program
    debugger::add("archive::extract() - {"+program$+" "+parameter$+"}")
    program = RunProgram(program$, parameter$, GetCurrentDirectory(), #PB_Program_Open|#PB_Program_Hide|#PB_Program_Read)
    If Not program
      debugger::add("archive::extract() - Error: could not start program")
      ProcedureReturn #False
    EndIf
    
    While ProgramRunning(program)
      If AvailableProgramOutput(program)
        debugger::add("archive::extract() -| "+ReadProgramString(program))
      EndIf
      Delay(1)
    Wend
    exit = ProgramExitCode(program)
    CloseProgram(program)
    If exit = 0
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
    
  EndProcedure
  
  Procedure pack(archive$, directory$)
    
    Protected root$
    Protected program$, parameter$
    Protected program, exit
    
    DeleteFile(archive$, #PB_FileSystem_Force)
    
    If FileSize(directory$) <> -2
      debugger::add("archive::pack() - Error: Cannot find source directory {"+directory$+"}")
      ProcedureReturn #False
    EndIf
    
    ; 7z will put files in subdir with respect to current working dir!
    directory$  = misc::path(directory$) ; single / at the end
    root$       = GetPathPart(Left(directory$, Len(directory$)-1))
    directory$  = GetFilePart(Left(directory$, Len(directory$)-1))
    directory$  = misc::path(directory$)+"*"
    
    ; define program
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        program$ = "7z/7z.exe"
        parameter$ = "a "+#DQUOTE$+archive$+#DQUOTE$+" "+#DQUOTE$+directory$+#DQUOTE$
    CompilerEndSelect
    
    ; start program
    debugger::add("archive::pack() - {"+program$+" "+parameter$+"}")
    program = RunProgram(program$, parameter$, root$, #PB_Program_Open|#PB_Program_Hide|#PB_Program_Read)
    If Not program
      debugger::add("archive::pack() - Error: could not start program")
      ProcedureReturn #False
    EndIf
    
    While ProgramRunning(program)
      If AvailableProgramOutput(program)
        debugger::add("archive::pack() -| "+ReadProgramString(program))
      EndIf
      Delay(1)
    Wend
    exit = ProgramExitCode(program)
    CloseProgram(program)
    If exit = 0
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
    
  EndProcedure
  
  
EndModule

