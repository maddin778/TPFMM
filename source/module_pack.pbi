﻿; COMMENT: a separate "pack" module is not really required... maybe this will be merge to "windowPack"


DeclareModule pack
  EnableExplicit
  
  #EXTENSION = "tpfmp"
  
  Structure packItem
    id$         ; folder name
    name$       ; display name
    download$   ; download: source/ID/fileID
  EndStructure
  
  ; functions
  Declare create(name$="", author$="")
  Declare free(*pack)
  Declare open(file$)
  Declare save(*pack, file$)
  Declare isPack(*pack)
  
  Declare setName(*pack, name$)
  Declare.s getName(*pack)
  Declare setAuthor(*pack, author$)
  Declare.s getAuthor(*pack)
  Declare addItem(*pack, *item.packItem)
  Declare getItems(*pack, List items())
  Declare removeItem(*pack, id$)
  
EndDeclareModule

XIncludeFile "module_debugger.pbi"

Module pack
  UseModule debugger
  
  Global NewMap packs()
  Global mutex = CreateMutex()
  
  Structure pack
    name$
    author$
    List items.packItem()
    mutex.i           ; for operations on this pack
  EndStructure
  
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create(name$ = "", author$ = "")
    Protected *pack.pack
    
    *pack = AllocateStructure(pack)
    *pack\name$   = name$
    *pack\author$ = author$
    *pack\mutex   = CreateMutex()
    
    LockMutex(mutex)
    AddMapElement(packs(), Str(*pack), #PB_Map_NoElementCheck)
    UnlockMutex(mutex)
    
    ProcedureReturn *pack
  EndProcedure
  
  Procedure isPack(*pack)
    Protected valid.i
    LockMutex(mutex)
    valid = FindMapElement(packs(), Str(*pack))
    UnlockMutex(mutex)
    ProcedureReturn valid
  EndProcedure
  
  Procedure free(*pack.pack)
    If Not isPack(*pack)
      deb("pack:: trying to free invalid pack")
      ProcedureReturn #False
    EndIf
    
    LockMutex(mutex)
    DeleteMapElement(packs(), Str(*pack))
    UnlockMutex(mutex)
    FreeMutex(*pack\mutex)
    FreeStructure(*pack)
  EndProcedure
  
  Procedure open(file$)
    Protected json
    Protected *pack.pack, packMutex
    
    json = LoadJSON(#PB_Any, file$)
    If Not json
      deb("pack:: could not open json "+file$)
      ProcedureReturn #False
    EndIf
    
    *pack = create()
    packMutex = *pack\mutex
    ExtractJSONStructure(JSONValue(json), *pack, pack)
    *pack\mutex = packMutex
    FreeJSON(json)
    
    ProcedureReturn *pack
  EndProcedure
  
  Procedure save(*pack.pack, file$)
    Protected json = CreateJSON(#PB_Any)
    InsertJSONStructure(JSONValue(json), *pack, pack)
    If Not SaveJSON(json, file$, #PB_JSON_PrettyPrint)
      deb("pack:: error writing json {"+file$+"}")
    EndIf
    FreeJSON(json)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure setName(*pack.pack, name$)
    *pack\name$ = name$
  EndProcedure
  
  Procedure.s getName(*pack.pack)
    ProcedureReturn *pack\name$
  EndProcedure
  
  Procedure setAuthor(*pack.pack, author$)
    *pack\author$ = author$
  EndProcedure
  
  Procedure.s getAuthor(*pack.pack)
    ProcedureReturn *pack\author$
  EndProcedure
  
  Procedure getItems(*pack.pack, List items.packItem())
    ClearList(items())
    LockMutex(*pack\mutex)
    CopyList(*pack\items(), items())
    LockMutex(*pack\mutex)
    ProcedureReturn ListSize(items())
  EndProcedure
  
  Procedure addItem(*pack.pack, *item.packItem)
    Protected add = #True
    LockMutex(*pack\mutex)
    ForEach *pack\items()
      If LCase(*pack\items()\id$) = LCase(*item\id$)
        deb("pack:: overwrite duplicate ID #"+*item\id$)
        ; overwrite with "new" entry in order to maybe get more recent information (name, download id, ...)
        CopyStructure(*item, *pack\items(), packItem) ; possible memory leak? does copyStructure clear the old strings ? TODO check this
        
        add = #False
        Break
      EndIf
    Next
    If add
      LastElement(*pack\items())
      AddElement(*pack\items())
      CopyStructure(*item, *pack\items(), packItem)
    EndIf
    UnlockMutex(*pack\mutex)
    ProcedureReturn add
  EndProcedure
  
  Procedure removeItem(*pack.pack, id$)
    LockMutex(*pack\mutex)
    ForEach *pack\items()
      If *pack\items()\id$
        DeleteElement(*pack\items())
        Break
      EndIf
    Next
    UnlockMutex(*pack\mutex)
  EndProcedure
  
EndModule
