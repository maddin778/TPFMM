
XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowSettings.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_mods.h.pbi"
XIncludeFile "module_repository.h.pbi"
XIncludeFile "module_modInformation.pbi"

DeclareModule windowMain
  EnableExplicit
  
  Global window, dialog
  
  Macro gadget(name)
    DialogGadget(windowMain::dialog, name)
  EndMacro
    
  Enumeration FormMenu
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      #PB_Menu_Quit
      #PB_Menu_Preferences
      #PB_Menu_About
    CompilerEndIf
    #MenuItem_AddMod
    #MenuItem_ExportList
    #MenuItem_ShowBackups
    #MenuItem_ShowDownloads
    #MenuItem_Homepage
    #MenuItem_License
  EndEnumeration
  
  Enumeration #PB_Event_FirstCustomValue
    #Event_Repo_Show_Selection
  EndEnumeration
  
  Enumeration progress
    #Progress_Hide      = -1
    #Progress_NoChange  = -2
  EndEnumeration
  
  Declare create()
  
  Declare stopGUIupdate(stop = #True)
  Declare setColumnWidths(Array widths(1))
  Declare getColumnWidth(column)
  
  Declare progressMod(percent, text$=Chr(1))
  Declare progressRepo(percent, text$=Chr(1))
  
  Declare repoFindModAndDownload(source$, id.q, fileID.q = 0)
  
EndDeclareModule



Module windowMain

  ; rightclick menu on library gadget
  Global MenuLibrary
  Enumeration FormMenu
    #MenuItem_Information
    #MenuItem_Backup
    #MenuItem_Uninstall
    #MenuItem_SearchModOnline
    #MenuItem_ModWebsite
    #MenuItem_ModFolder
    #MenuItem_RepositoryRefresh
    #MenuItem_RepositoryClearCache
  EndEnumeration
  
  Global xml ; keep xml dialog in order to manipulate for "selectFiles" dialog
  
  ;- Timer
  Global TimerMainGadgets = 101
  
  ; other stuff
  Global NewMap PreviewImages.i()
  Global _noUpdate
  
  Declare repoDownload()
  Declare modOpenModFolder()
  Declare modInformation()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  
  Procedure resize()
    ResizeImage(images::Images("headermain"), WindowWidth(window), 8, #PB_Image_Raw)
    SetGadgetState(gadget("headerMain"), ImageID(images::Images("headermain")))
  EndProcedure
  
  Procedure updateModButtons()
    Protected i, numSelected, numCanUninstall, numCanBackup
    Protected *mod.mods::mod
    Protected text$, author$
    
    If _noUpdate
      ProcedureReturn #False
    EndIf
    
    
    numSelected     = 0
    numCanUninstall = 0
    numCanBackup    = 0
    
    For i = 0 To CountGadgetItems(gadget("modList")) - 1
      *mod = ListIcon::GetListItemData(gadget("modList"), i)
      If Not *mod
        Continue
      EndIf
      
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected
        numSelected + 1
        If mods::canUninstall(*mod)
          numCanUninstall + 1
        EndIf
        If mods::canBackup(*mod)
          numCanBackup + 1
        EndIf
      EndIf
    Next
    
    If numSelected = 1
      DisableGadget(gadget("modInformation"), #False)
    Else
      DisableGadget(gadget("modInformation"), #True)
    EndIf
    
    If numCanBackup = 0
      DisableGadget(gadget("modBackup"),  #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Backup, #True)
    Else
      DisableGadget(gadget("modBackup"), #False)
      DisableMenuItem(MenuLibrary, #MenuItem_Backup, #False)
    EndIf
    
    If numCanUninstall = 0
      DisableGadget(gadget("modUninstall"),  #True)
      DisableMenuItem(MenuLibrary, #MenuItem_Uninstall, #True)
    Else
      DisableGadget(gadget("modUninstall"),  #False)
      DisableMenuItem(MenuLibrary, #MenuItem_Uninstall, #False)
    EndIf
    
    If numCanBackup > 1
      SetGadgetText(gadget("modBackup"),     locale::l("main","backup_pl"))
      SetMenuItemText(MenuLibrary, #MenuItem_Backup,    locale::l("main","backup_pl"))
    Else
      SetGadgetText(gadget("modBackup"),     locale::l("main","backup"))
      SetMenuItemText(MenuLibrary, #MenuItem_Backup,    locale::l("main","backup"))
    EndIf
    
    If numCanUninstall > 1
      SetGadgetText(gadget("modUninstall"),  locale::l("main","uninstall_pl"))
      SetMenuItemText(MenuLibrary, #MenuItem_Uninstall, locale::l("main","uninstall_pl"))
    Else
      SetGadgetText(gadget("modUninstall"),  locale::l("main","uninstall"))
      SetMenuItemText(MenuLibrary, #MenuItem_Uninstall, locale::l("main","uninstall"))
    EndIf
    
    If numSelected = 1
      ; one mod selected
      ; display image
      *mod = ListIcon::GetListItemData(gadget("modList"), GetGadgetState(gadget("modList")))
      
      Protected im
      im = mods::getPreviewImage(*mod)
      If IsImage(im)
        ; display image
        If GetGadgetState(gadget("modPreviewImage")) <> ImageID(im)
          SetGadgetState(gadget("modPreviewImage"), ImageID(im))
        EndIf
      Else
        ; else: display normal logo
        If GetGadgetState(gadget("modPreviewImage")) <> ImageID(images::Images("logo"))
          SetGadgetState(gadget("modPreviewImage"), ImageID(images::Images("logo")))
        EndIf
      EndIf
      
      ; link to mod in repo
      DisableMenuItem(MenuLibrary, #MenuItem_SearchModOnline, #False)
      DisableGadget(gadget("modUpdate"), #False)
      If *mod\aux\tfnetMod Or *mod\aux\workshopMod ; link to online mod known
        SetMenuItemText(MenuLibrary, #MenuItem_SearchModOnline, locale::l("main", "show_online"))
        SetGadgetText(gadget("modUpdate"), locale::l("main", "download_current"))
      Else ; link unknown
        SetMenuItemText(MenuLibrary, #MenuItem_SearchModOnline, locale::l("main", "search_online"))
        SetGadgetText(gadget("modUpdate"), locale::l("main", "search_online"))
      EndIf
      
      ; website 
      If *mod\url$ Or *mod\aux\tfnetID Or *mod\aux\workshopID
        DisableMenuItem(MenuLibrary, #MenuItem_ModWebsite, #False)
      Else
        DisableMenuItem(MenuLibrary, #MenuItem_ModWebsite, #True)
      EndIf
      
      
    Else
      ; multiple mods or none selected
      
      If GetGadgetState(gadget("modPreviewImage")) <> ImageID(images::Images("logo"))
        SetGadgetState(gadget("modPreviewImage"), ImageID(images::Images("logo")))
      EndIf
      
      DisableGadget(gadget("modUpdate"), #True)
      
      DisableMenuItem(MenuLibrary, #MenuItem_SearchModOnline, #True)
      DisableMenuItem(MenuLibrary, #MenuItem_ModWebsite, #True)
      
    EndIf
    
    
  EndProcedure
  
  Procedure updateRepoButtons()
    Protected numSelected, numCanDownload
    Protected *repoMod.repository::mod
    Protected i
    
    If _noUpdate
      ProcedureReturn #False
    EndIf
    
    numSelected = 0
    numCanDownload = 0
    
    For i = 0 To CountGadgetItems(gadget("repoList")) - 1
      *repoMod = GetGadgetItemData(gadget("repoList"), i)
      If Not *repoMod
        Continue
      EndIf
      
      If GetGadgetItemState(gadget("repoList"), i) & #PB_ListIcon_Selected
        numSelected + 1
        If repository::canDownloadMod(*repoMod)
          numCanDownload + 1
        EndIf
      EndIf
    Next
    
    SetGadgetText(gadget("repoInstall"), locale::l("main", "install"))
    
    If numCanDownload = 1
      DisableGadget(gadget("repoInstall"), #False)
      
      *repoMod = GetGadgetItemData(gadget("repoList"), GetGadgetState(gadget("repoList")))
      If *repoMod\installed
        SetGadgetText(gadget("repoInstall"), locale::l("main", "install_update"))
      EndIf
      
    Else
      DisableGadget(gadget("repoInstall"), #True)
    EndIf
    
    If numSelected = 1
      DisableGadget(gadget("repoWebsite"), #False)
    Else
      DisableGadget(gadget("repoWebsite"), #True)
    EndIf
    
  EndProcedure
  
  
  Procedure close()
    HideWindow(window, #True)
    main::exit()
  EndProcedure
  
  ;-------------------------------------------------
  ;- TIMER
  
  Procedure TimerMain()
    Static LastDir$ = ""
    If EventTimer() = TimerMainGadgets
      
      ; check changed working Directory
      If LastDir$ <> main::gameDirectory$
        Debug "windowMain::timerMain() - Working Directory Changed"
        LastDir$ = main::gameDirectory$
        If misc::checkGameDirectory(main::gameDirectory$) = 0
          ; ok
        Else
          main::gameDirectory$ = ""
          windowSettings::show()
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  ;- MENU
  
  Procedure MenuItemHomepage()
    misc::openLink(main::WEBSITE$) ; Download Page TFMM (Train-Fever.net)
  EndProcedure
  
  Procedure MenuItemLicense()
    Protected TPFMM$, ThirdParty$, About$
    
    TPFMM$ = "Transport Fever Mod Manager (" + main::VERSION$ + ")" + #CRLF$ +
             "Copyright � 2014-"+FormatDate("%yyyy", Date())+" Alexander N�hring" + #CRLF$ +
             "Distributed on https://www.transportfevermods.com/" + #CRLF$ +
             "  and https://www.transportfever.net/"
    
    CompilerSelect #PB_Compiler_OS 
      CompilerCase #PB_OS_Windows
        ThirdParty$ = "Used Third-Party Software:" + #CRLF$ + 
                      "7-Zip Copyright � 1999-2016 Igor Pavlov." + #CRLF$ +
                      "  License: GNU LGPL http://www.gnu.org/" + #CRLF$ +
                      "  unRAR � Alexander Roshal" + #CRLF$ + 
                      "LUA Copyright � 1994-2017 Lua.org, PUC-Rio." + #CRLF$ + 
                      "  License: MIT http://www.opensource.org/licenses/mit-license.html"
        
      CompilerCase #PB_OS_Linux
        ThirdParty$ = "Used Third-Party Software:" + #CRLF$ + 
                      "LUA Copyright � 1994-2017 Lua.org, PUC-Rio." + #CRLF$ + 
                      "  License: MIT http://www.opensource.org/licenses/mit-license.html" + #CRLF$ + 
                      #CRLF$ + 
                      "Additional required packages: zip, unzip, unrar"
        
    CompilerEndSelect
    
    About$ = TPFMM$ + #CRLF$ + #CRLF$ + ThirdParty$
      
    MessageRequester("About", About$, #PB_MessageRequester_Info)
  EndProcedure
  
  Procedure MenuItemSettings() ; open settings window
    windowSettings::show()
  EndProcedure
  
  Procedure MenuItemExport()
    mods::exportList()
  EndProcedure
  
  ;- GADGETS
      
  Procedure modAddNewMod()
    Protected file$
    If FileSize(main::gameDirectory$) <> -2
      ProcedureReturn #False
    EndIf
    file$ = OpenFileRequester(locale::l("management","select_mod"), "", locale::l("management","files_archive")+"|*.zip;*.rar|"+locale::l("management","files_all")+"|*.*", 0, #PB_Requester_MultiSelection)
    While file$
      If FileSize(file$) > 0
        mods::install(file$)
      EndIf
      file$ = NextSelectedFileName()
    Wend
  EndProcedure
  
  Procedure modUninstall() ; Uninstall selected mods (delete from HDD)
    debugger::Add("windowMain::GadgetButtonUninstall()")
    Protected *mod.mods::mod
    Protected i, count, result
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(gadget("modList")) - 1
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(gadget("modList"), i)
        If mods::canUninstall(*mod)
          count + 1
        EndIf
      EndIf
    Next i
    If count > 0
      If count = 1
        ClearMap(strings$())
        strings$("name") = *mod\name$
        result = MessageRequester(locale::l("main","uninstall"), locale::getEx("management", "uninstall1", strings$()), #PB_MessageRequester_YesNo)
      Else
        ClearMap(strings$())
        strings$("count") = Str(count)
        result = MessageRequester(locale::l("main","uninstall_pl"), locale::getEx("management", "uninstall2", strings$()), #PB_MessageRequester_YesNo)
      EndIf
      
      If result = #PB_MessageRequester_Yes
        For i = 0 To CountGadgetItems(gadget("modList")) - 1
          If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected
            *mod = ListIcon::GetListItemData(gadget("modList"), i)
            If mods::canUninstall(*mod)
;               debugger::add("windowMain::GadgetButtonUninstall() - {"+*mod\name$+"}")
              mods::uninstall(*mod\tpf_id$)
            EndIf
          EndIf
        Next i
      EndIf
    EndIf
  EndProcedure
  
  Procedure modBackup()
    debugger::Add("windowMain::GadgetButtonBackup()")
    
    Protected *mod.mods::mod
    Protected i, count
    Protected backupFolder$
    Protected NewMap strings$()
    
    For i = 0 To CountGadgetItems(gadget("modList")) - 1
      If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected 
        *mod = ListIcon::GetListItemData(gadget("modList"), i)
        If mods::canBackup(*mod)
          count + 1
        EndIf
      EndIf
    Next i
    If count > 0
      
      For i = 0 To CountGadgetItems(gadget("modList")) - 1
        If GetGadgetItemState(gadget("modList"), i) & #PB_ListIcon_Selected
          *mod = ListIcon::GetListItemData(gadget("modList"), i)
          If mods::canBackup(*mod)
            mods::backup(*mod\tpf_id$)
          EndIf
        EndIf
      Next i
      
    EndIf
  EndProcedure
  
  Procedure modList()
    updateModButtons()
    
    Select EventType()
      Case #PB_EventType_LeftDoubleClick
        modInformation()
      Case #PB_EventType_RightClick
        DisplayPopupMenu(MenuLibrary, WindowID(windowMain::window))
    EndSelect
  EndProcedure
  
  Procedure websiteTrainFeverNet()
    misc::openLink("http://goo.gl/8Dsb40") ; Homepage (Train-Fever.net)
  EndProcedure
  
  Procedure websiteTrainFeverNetDownloads()
    misc::openLink("http://goo.gl/Q75VIM") ; Downloads / Filebase (Train-Fever.net)
  EndProcedure
  
  Procedure modPreviewImage()
    Protected event = EventType()
    If event = #PB_EventType_LeftClick
      If GetGadgetState(gadget("modPreviewImage")) = ImageID(images::Images("logo"))
        websiteTrainFeverNet()
      EndIf
    EndIf
  EndProcedure
  
  Procedure modFilterMods()
    mods::displayMods()
  EndProcedure
  
  Procedure modResetFilterMods()
    SetGadgetText(gadget("modFilterString"), "")
    SetActiveGadget(gadget("modFilterString"))
    mods::displayMods()
  EndProcedure
  
  Procedure modShowBackupFolder()
    If main::gameDirectory$
      misc::CreateDirectoryAll(main::gameDirectory$+"TPFMM/backups/")
      misc::openLink(main::gameDirectory$+"TPFMM/backups/")
    EndIf
  EndProcedure
  
  Procedure modShowDownloadFolder()
    If main::gameDirectory$
      misc::CreateDirectoryAll(main::gameDirectory$+"TPFMM/download/")
      misc::openLink(main::gameDirectory$+"TPFMM/download/")
    EndIf
  EndProcedure
  
  
  Procedure modInformation()
    Protected *mod.mods::mod
    
    *mod = ListIcon::GetListItemData(gadget("modList"), GetGadgetState(gadget("modList")))
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    modInformation::modInfoShow(*mod, xml, WindowID(window))
  EndProcedure
  
  Procedure modUpdate()
    debugger::add("windowMain::modUpdate()")
    ; currently, supprot only one selected mod in list
    ; if multiple mods selected, start "repoFindModAndDownload" for each mod
    ; for this, change repoFindModAndDownloadThread to wait for other instances to finish!
    
    Protected *mod.mods::mod, *repoMod.repository::mod
    Protected selected
    
    selected = GetGadgetState(gadget("modList"))
    If selected <> -1
      *mod = GetGadgetItemData(gadget("modList"), selected)
    EndIf
    
    
    If *mod
      ; get best fit repoMod (if any)
      ; if multiple defined, select same "installSource" or based on folder name
      
      If Not mods::update(*mod\tpf_id$)
        ; show mod in database
        repository::searchMod(*mod\name$) ; todo search author?
        SetGadgetState(gadget("panel"), 1)
      EndIf
      
    EndIf
  EndProcedure
  
  Procedure repoList()
    updateRepoButtons()
  EndProcedure
  
  Procedure MenuRepoListAuthor()
    Protected selected, *repoMod.repository::mod
    
    selected = GetGadgetState(gadget("repoList"))
    If selected <> -1
      *repoMod = GetGadgetItemData(gadget("repoList"), selected)
    EndIf
    
    If *repoMod
      SetGadgetText(gadget("repoFilterString"), *repoMod\author$)
      SetActiveGadget(gadget("repoFilterString"))
    EndIf
  EndProcedure
  
  Procedure repoListShowMenu()
    Protected selected, *repoMod.repository::mod
    Static menuID
    
    If menuID And IsMenu(MenuID)
      FreeMenu(MenuID)
    EndIf
    
    selected = GetGadgetState(gadget("repoList"))
    If selected <> -1
      *repoMod = GetGadgetItemData(gadget("repoList"), selected)
    EndIf
    
    If *repoMod
      menuID = CreatePopupMenu(#PB_Any)
      Protected NewMap strings$()
      If *repoMod\installed
        MenuItem(5000, locale::l("main", "install_update"))
      Else
        MenuItem(5000, locale::l("main", "install"))
      EndIf
      If Not repository::canDownloadMod(*repoMod)
        DisableMenuItem(menuID, 5000, #True)
      EndIf
      BindMenuEvent(menuID, 5000, @repoDownload())
      
      MenuBar()
      
      strings$("author") = *repoMod\author$
      MenuItem(5001, locale::getEx("repository", "more_author", strings$()))
      BindMenuEvent(menuID, 5001, @MenuRepoListAuthor())
      DisplayPopupMenu(menuID, WindowID(window))
    EndIf
  EndProcedure
  
  Procedure repoResetFilter()
    SetGadgetText(gadget("repoFilterString"), "")
    SetActiveGadget(gadget("repoFilterString"))
  EndProcedure
  
  Procedure repoWebsite()
    Protected item
    Protected *mod.repository::mod
    
    ; currently: only one file at a time! -> only get first selected
    
    ; get selected mod from list:
    item = GetGadgetState(gadget("repoList"))
    If item = -1
      ProcedureReturn #False
    EndIf
    
    *mod = GetGadgetItemData(gadget("repoList"), item)
    If Not *mod
      ProcedureReturn #False
    EndIf
    
    If *mod\url$
      misc::openLink(*mod\url$) ; open in browser
    EndIf
  EndProcedure
  
  ; repo download file selection window...
  
  Global dialogSelectFiles
  Global NewMap repoSelectFilesGadget()
  
  Procedure repoSelectFilesClose()
    DisableWindow(window, #False)
    SetActiveWindow(window)
    If dialogSelectFiles And IsDialog(dialogSelectFiles)
      CloseWindow(DialogWindow(dialogSelectFiles))
      FreeDialog(dialogSelectFiles)
    EndIf
  EndProcedure
  
  Procedure repoSelectFilesDownload()
    Protected *file.repository::file
    Protected *repo_mod.repository::mod
    If dialogSelectFiles And IsDialog(dialogSelectFiles)
      *repo_mod = GetGadgetData(DialogGadget(dialogSelectFiles, "selectDownload"))
      ; find selected 
      ForEach repoSelectFilesGadget()
        If repoSelectFilesGadget() And IsGadget(repoSelectFilesGadget())
          If GetGadgetState(repoSelectFilesGadget())
            ; init download if selected
            *file = GetGadgetData(repoSelectFilesGadget())
            
            repository::downloadMod(*repo_mod\source$, *repo_mod\id, *file\fileID)
          EndIf
        EndIf
      Next
    EndIf
    repoSelectFilesClose()
  EndProcedure
  
  Procedure repoSelectFilesUpdateButtons()
    ForEach repoSelectFilesGadget()
      If repoSelectFilesGadget() And IsGadget(repoSelectFilesGadget())
        If GetGadgetState(repoSelectFilesGadget())
          DisableGadget(DialogGadget(dialogSelectFiles, "selectDownload"), #False)
          ProcedureReturn #True
        EndIf
      EndIf
    Next
    DisableGadget(DialogGadget(dialogSelectFiles, "selectDownload"), #True)
    ProcedureReturn #False
  EndProcedure
  
  Procedure repoDownloadShowSelection(*repo_mod.repository::mod)
    Protected *nodeBase, *node
    Protected *file
    
    If IsDialog(dialogSelectFiles)
      If IsWindow(DialogWindow(dialogSelectFiles))
        CloseWindow(DialogWindow(dialogSelectFiles))
      EndIf
      FreeDialog(dialogSelectFiles)
    EndIf
    
    If IsXML(xml)
      *nodeBase = XMLNodeFromID(xml, "selectBox")
      If *nodeBase
        misc::clearXMLchildren(*nodeBase)
        ; add a checkbox for each file in mod
        ForEach *repo_mod\files()
          *node = CreateXMLNode(*nodeBase, "checkbox", -1)
          If *node
            SetXMLAttribute(*node, "name", Str(*repo_mod\files()))
            SetXMLAttribute(*node, "text", *repo_mod\files()\filename$)
          EndIf
        Next
        
        ; show window now
        dialogSelectFiles = CreateDialog(#PB_Any)
        If dialogSelectFiles And OpenXMLDialog(dialogSelectFiles, xml, "selectFiles", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(window))
          
          ; get gadgets
          ClearMap(repoSelectFilesGadget())
          ForEach *repo_mod\files()
            *file = *repo_mod\files()
            If repository::canDownloadFile(*file)
              repoSelectFilesGadget(Str(*file)) = DialogGadget(dialogSelectFiles, Str(*file))
              SetGadgetData(repoSelectFilesGadget(Str(*file)), *file)
              BindGadgetEvent(repoSelectFilesGadget(Str(*file)), @repoSelectFilesUpdateButtons())
            EndIf
          Next
          
          SetWindowTitle(DialogWindow(dialogSelectFiles), locale::l("main","select_files"))
          SetGadgetText(DialogGadget(dialogSelectFiles, "selectText"), locale::l("main","select_files_text"))
          SetGadgetText(DialogGadget(dialogSelectFiles, "selectCancel"), locale::l("main","cancel"))
          SetGadgetText(DialogGadget(dialogSelectFiles, "selectDownload"), locale::l("main","download"))
          
          RefreshDialog(dialogSelectFiles)
          HideWindow(DialogWindow(dialogSelectFiles), #False, #PB_Window_WindowCentered)
          
          BindGadgetEvent(DialogGadget(dialogSelectFiles, "selectCancel"), @repoSelectFilesClose())
          BindGadgetEvent(DialogGadget(dialogSelectFiles, "selectDownload"), @repoSelectFilesDownload())
          SetGadgetData(DialogGadget(dialogSelectFiles, "selectDownload"), *repo_mod)
          
          DisableGadget(DialogGadget(dialogSelectFiles, "selectDownload"), #True)
          
          BindEvent(#PB_Event_CloseWindow, @repoSelectFilesClose(), DialogWindow(dialogSelectFiles))
          
          DisableWindow(window, #True)
          ProcedureReturn #True
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  Procedure repoEventShowSelection()
    Protected *repoMod
    *repoMod = EventData()
    If *repoMod
      repoDownloadShowSelection(*repoMod)
    EndIf
  EndProcedure
  
  Procedure repoDownload()
    ; download and install mod from source
    Protected item, url$, nFiles
    Protected *repo_mod.repository::mod, *file.repository::file
    Protected download.repository::download
    
    ; currently: only one file at a time! -> only get first selected
    
    ; get selected mod from list:
    item = GetGadgetState(gadget("repoList"))
    If item = -1
      ProcedureReturn #False
    EndIf
    
    *repo_mod = GetGadgetItemData(gadget("repoList"), item)
    If Not *repo_mod
      ProcedureReturn #False
    EndIf
    
    ; check if download is available!
    nFiles = repository::canDownloadMod(*repo_mod)
    If Not nFiles
      ProcedureReturn
    EndIf
    
    ; single file? start download!
    If nFiles = 1
      ForEach *repo_mod\files()
        *file = *repo_mod\files()
        If repository::canDownloadFile(*file) ; search for the single downloadable file
          repository::downloadMod(*repo_mod\source$, *repo_mod\id, *file\fileID)
          ProcedureReturn #True
        EndIf
      Next
    EndIf
    
    ; more files? show selection window
    
    ; manipulate xml before opening dialog
    repoDownloadShowSelection(*repo_mod)
    
    ProcedureReturn #False
  EndProcedure
  
  Procedure repoRefresh()
    repository::refresh()
  EndProcedure
  
  Procedure repoClearCache()
    repository::clearCache()
    MessageRequester(locale::l("main","repo_clear_title"), locale::l("main","repo_clear_text"), #PB_MessageRequester_Info)
  EndProcedure
  
  Procedure searchModOnline()
    ; get selected mod from list
    
    Protected *mod.mods::mod
    Protected *repoMod.repository::mod
    Protected item
    
    item = GetGadgetState(gadget("modList"))
    If item <> -1
      *mod = GetGadgetItemData(gadget("modList"), item)
      If *mod
        *repoMod = repository::getRepoMod(*mod)
        If *repoMod
          repository::selectModInList(*repoMod)
          SetGadgetState(gadget("panel"), 1)
        Else
          repository::searchMod(*mod\name$) ; todo search author?
          SetGadgetState(gadget("panel"), 1)
        EndIf
      EndIf
    EndIf
    
  EndProcedure
  
  Procedure modShowWebsite()
    Protected item, *mod.mods::mod
    item = GetGadgetState(gadget("modList"))
    If item <> -1
      *mod = GetGadgetItemData(gadget("modList"), item)
      If *mod
        If *mod\url$
          misc::openLink(*mod\url$)
        ElseIf *mod\aux\tfnetID
          misc::openLink("https://www.transportfever.net/filebase/index.php/Entry/"+*mod\aux\tfnetID)
        ElseIf *mod\aux\workshopID
          misc::openLink("http://steamcommunity.com/sharedfiles/filedetails/?id="+*mod\aux\workshopID)
        EndIf
        
        ProcedureReturn #True
      EndIf
    EndIf
    ProcedureReturn #True
  EndProcedure
  
  Procedure modOpenModFolder()
    Protected item, *mod.mods::mod
    item = GetGadgetState(gadget("modList"))
    If item <> -1
      *mod = GetGadgetItemData(gadget("modList"), item)
      If *mod 
        misc::openLink(mods::getModFolder(*mod\tpf_id$, *mod\aux\type$))
        ProcedureReturn #True
      EndIf
    EndIf
    ProcedureReturn #True
  EndProcedure
  
  ; DRAG & DROP
  
  Procedure HandleDroppedFiles()
    Protected count, i
    Protected file$, files$
    
    files$ = EventDropFiles()
    
    debugger::Add("dropped files:")
    count  = CountString(files$, Chr(10)) + 1
    For i = 1 To count
      file$ = StringField(files$, i, Chr(10))
      mods::install(file$)
    Next i
  EndProcedure
  
  Procedure getStatusBarHeight()
    Protected window, bar, height
    window = OpenWindow(#PB_Any, 0, 0, 100, 100, "Status Bar", #PB_Window_SystemMenu|#PB_Window_Invisible|#PB_Window_SizeGadget)
    If window
      bar = CreateStatusBar(#PB_Any, WindowID(window))
      AddStatusBarField(#PB_Ignore)
      StatusBarText(bar, 0, "Status Bar", #PB_StatusBar_BorderLess)
      height = StatusBarHeight(bar)
      FreeStatusBar(bar)
      CloseWindow(window)
    EndIf
    ProcedureReturn height
  EndProcedure
  
  Procedure progressMod(percent, text$=Chr(1))
    Static max
    If max <> 100
      max = 100
      SetGadgetAttribute(gadget("progressModBar"), #PB_ProgressBar_Maximum, max)
    EndIf
    
    If percent = #Progress_Hide
      HideGadget(gadget("progressModBar"), #True)
    Else
      HideGadget(gadget("progressModBar"), #False)
      SetGadgetState(gadget("progressModBar"), percent)
    EndIf
    
    If text$ <> Chr(1)
      SetGadgetText(gadget("progressModText"), text$)
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        RefreshDialog(dialog)
        ; causes segmentation violation in Linux
      CompilerEndIf
    EndIf
  EndProcedure
  
  Procedure progressRepo(percent, text$=Chr(1))
    Static max
    If max <> 100
      max = 100
      SetGadgetAttribute(gadget("progressRepoBar"), #PB_ProgressBar_Maximum, max)
    EndIf
    
    If percent <> #Progress_NoChange
      If percent = #Progress_Hide
        HideGadget(gadget("progressRepoBar"), #True)
      Else
        HideGadget(gadget("progressRepoBar"), #False)
        SetGadgetState(gadget("progressRepoBar"), percent)
      EndIf
    EndIf
    
    If text$ <> Chr(1)
      SetGadgetText(gadget("progressRepoText"), text$)
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        RefreshDialog(dialog)
        ; causes segmentation violation in Linux
      CompilerEndIf
    EndIf
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create()
    UseModule locale ; import namespace "locale" for shorthand "l()" access
    
    DataSection
      mainDialogXML:
      IncludeBinary "dialogs/main.xml"
      mainDialogXMLend:
    EndDataSection
    
    ; open dialog
    xml = CatchXML(#PB_Any, ?mainDialogXML, ?mainDialogXMLend - ?mainDialogXML)
    If Not xml Or XMLStatus(xml) <> #PB_XML_Success
      MessageRequester("Critical Error", "Could not read window definition!", #PB_MessageRequester_Error)
      End
    EndIf
    
    ; dialog does not take menu height and statusbar height into account
    ; workaround: placeholder node in dialog tree with required offset.
    SetXMLAttribute(XMLNodeFromID(xml, "placeholder"), "margin", "bottom:"+Str(MenuHeight()-8)) ; getStatusBarHeight()
    
    dialog = CreateDialog(#PB_Any)
    If Not dialog Or Not OpenXMLDialog(dialog, xml, "main")
      MessageRequester("Critical Error", "Could not open main window!", #PB_MessageRequester_Error)
      End
    EndIf
    
    window = DialogWindow(dialog)
    
    
    ; Set window events & timers
    AddWindowTimer(window, TimerMainGadgets, 100)
    BindEvent(#PB_Event_SizeWindow, @resize(), window)
    BindEvent(#PB_Event_MaximizeWindow, @resize(), window)
    BindEvent(#PB_Event_RestoreWindow, @resize(), window)
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    BindEvent(#PB_Event_Timer, @TimerMain(), window)
    BindEvent(#PB_Event_WindowDrop, @HandleDroppedFiles(), window)
    
    BindEvent(#Event_Repo_Show_Selection, @repoEventShowSelection())
    
    ; initialize gadgets
    
    SetGadgetItemText(gadget("panel"), 0,       l("main","mods"))
    SetGadgetItemText(gadget("panel"), 1,       l("main","repository"))
    
    RemoveGadgetColumn(gadget("modList"), 0)
    AddGadgetColumn(gadget("modList"), 0,       l("main","name"), 240)
    AddGadgetColumn(gadget("modList"), 1,       l("main","author"), 90)
    AddGadgetColumn(gadget("modList"), 2,       l("main","category"), 90)
    AddGadgetColumn(gadget("modList"), 3,       l("main","version"), 60)
    SetGadgetText(gadget("modFilterFrame"),     l("main","filter"))
    SetGadgetText(gadget("modFilterHidden"),    l("main","filter_hidden"))
    SetGadgetText(gadget("modFilterVanilla"),   l("main","filter_vanilla"))
    SetGadgetText(gadget("modManagementFrame"), l("main","management"))
    SetGadgetText(gadget("modInformation"),     l("main","information"))
    SetGadgetText(gadget("modSettings"),        l("main","settings"))
    SetGadgetText(gadget("modUpdate"),          l("main","search_online"))
    SetGadgetText(gadget("modBackup"),          l("main","backup"))
    SetGadgetText(gadget("modUninstall"),       l("main","uninstall"))
    
    SetGadgetText(gadget("repoFilterFrame"),    l("main","filter"))
    SetGadgetText(gadget("repoManagementFrame"), l("main","management"))
    SetGadgetText(gadget("repoWebsite"),        l("main","mod_website"))
    SetGadgetText(gadget("repoInstall"),        l("main","install"))
    
    
    ; Bind Gadget Events
    BindGadgetEvent(gadget("modInformation"),   @modInformation())
    BindGadgetEvent(gadget("modUpdate"),        @modUpdate())
    BindGadgetEvent(gadget("modBackup"),        @modBackup())
    BindGadgetEvent(gadget("modUninstall"),     @modUninstall())
    BindGadgetEvent(gadget("modList"),          @modList())
    BindGadgetEvent(gadget("modFilterString"),  @modFilterMods(), #PB_EventType_Change)
    BindGadgetEvent(gadget("modFilterReset"),   @modResetFilterMods())
    BindGadgetEvent(gadget("modFilterHidden"),  @modFilterMods())
    BindGadgetEvent(gadget("modFilterVanilla"), @modFilterMods())
    BindGadgetEvent(gadget("modFilterFolder"),  @modFilterMods(), #PB_EventType_Change)
    
    
    BindGadgetEvent(gadget("repoList"),         @repoList())
    BindGadgetEvent(gadget("repoList"),         @repoListShowMenu(), #PB_EventType_RightClick)
    BindGadgetEvent(gadget("repoFilterReset"),  @repoResetFilter())
    BindGadgetEvent(gadget("repoWebsite"),      @repoWebsite())
    BindGadgetEvent(gadget("repoInstall"),      @repoDownload())
    
    
    ; create shortcuts
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      ; Mac OS X has predefined shortcuts
      AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_P, #PB_Menu_Preferences)
      AddKeyboardShortcut(window, #PB_Shortcut_Alt | #PB_Shortcut_F4, #PB_Menu_Quit)
      AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_L, #PB_Menu_About)
    CompilerEndIf
    AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_O, #MenuItem_AddMod)
    AddKeyboardShortcut(window, #PB_Shortcut_F1, #MenuItem_Homepage)
    
    
    ; Menu
    CreateMenu(0, WindowID(window))
    CompilerIf #PB_Compiler_OS <> #PB_OS_MacOS
      MenuTitle(l("menu","file"))
    CompilerEndIf
    MenuItem(#PB_Menu_Preferences, l("menu","settings") + Chr(9) + "Ctrl + P")
    MenuItem(#PB_Menu_Quit, l("menu","close") + Chr(9) + "Alt + F4")
    MenuTitle(l("menu","mods"))
    MenuItem(#MenuItem_AddMod, l("menu","mod_add") + Chr(9) + "Ctrl + O")
    MenuItem(#MenuItem_ExportList, l("menu","mod_export"))
    MenuBar()
    MenuItem(#MenuItem_ShowBackups, l("menu","show_backups"))
    MenuItem(#MenuItem_ShowDownloads, l("menu","show_downloads"))
    MenuTitle(l("menu","repository"))
    MenuItem(#MenuItem_RepositoryRefresh, l("menu","repo_refresh"))
    MenuItem(#MenuItem_RepositoryClearCache, l("menu","repo_clear"))
    MenuTitle(l("menu","about"))
    MenuItem(#MenuItem_Homepage, l("menu","homepage") + Chr(9) + "F1")
    MenuItem(#PB_Menu_About, l("menu","license") + Chr(9) + "Ctrl + L")
    
    ; Menu Events
    BindMenuEvent(0, #PB_Menu_Preferences, @MenuItemSettings())
    BindMenuEvent(0, #PB_Menu_Quit, main::@exit())
    BindMenuEvent(0, #MenuItem_AddMod, @modAddNewMod())
    BindMenuEvent(0, #MenuItem_ExportList, @MenuItemExport())
    BindMenuEvent(0, #MenuItem_ShowBackups, @modShowBackupFolder())
    BindMenuEvent(0, #MenuItem_ShowDownloads, @modShowDownloadFolder())
    BindMenuEvent(0, #MenuItem_RepositoryRefresh, @repoRefresh())
    BindMenuEvent(0, #MenuItem_RepositoryClearCache, @repoClearCache())
    BindMenuEvent(0, #MenuItem_Homepage, @MenuItemHomepage())
    BindMenuEvent(0, #PB_Menu_About, @MenuItemLicense())
    
    SetGadgetText(gadget("version"), main::VERSION$)
    
    ; OS specific
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        SetWindowTitle(window, GetWindowTitle(window) + " for Windows")
        ListIcon::DefineListCallback(gadget("modList"))
      CompilerCase #PB_OS_Linux
        SetWindowTitle(window, GetWindowTitle(window) + " for Linux")
      CompilerCase #PB_OS_MacOS
        SetWindowTitle(window, GetWindowTitle(window) + " for MacOS")
    CompilerEndSelect
    
    
    ; indicate testmode in window title
    If main::_TESTMODE
      SetWindowTitle(window, GetWindowTitle(window) + " (Test Mode Enabled)")
    EndIf
    
    
    ; load images
    ResizeImage(images::Images("headermain"), GadgetWidth(gadget("headerMain")), GadgetHeight(gadget("headerMain")), #PB_Image_Raw)
    SetGadgetState(gadget("headerMain"), ImageID(images::Images("headermain")))
    SetGadgetState(gadget("modPreviewImage"), ImageID(images::Images("logo")))
    
    
    ; right click menu on mod item
    MenuLibrary = CreatePopupImageMenu(#PB_Any)
    MenuItem(#MenuItem_ModFolder, l("main","open_folder"))
    MenuItem(#MenuItem_Backup, l("main","backup"), ImageID(images::Images("icon_backup")))
    MenuItem(#MenuItem_Uninstall, l("main","uninstall"), ImageID(images::Images("no")))
    MenuBar()
    MenuItem(#MenuItem_SearchModOnline, l("main", "search_online"))
    MenuItem(#MenuItem_ModWebsite, l("main", "mod_website"))
    
    
    ;AddKeyboardShortcut(window, #PB_Shortcut_Delete, #MenuItem_Uninstall) ; should only work when gadget is active!
    
    BindMenuEvent(MenuLibrary, #MenuItem_ModFolder, @modOpenModFolder())
    BindMenuEvent(MenuLibrary, #MenuItem_Backup, @modBackup())
    BindMenuEvent(MenuLibrary, #MenuItem_Uninstall, @modUninstall())
    BindMenuEvent(MenuLibrary, #MenuItem_SearchModOnline, @searchModOnline())
    BindMenuEvent(MenuLibrary, #MenuItem_ModWebsite, @modShowWebsite())
    
    
    
    ; Drag & Drop
    EnableWindowDrop(window, #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
    
    
    ; register mods module
    mods::register(window, gadget("modList"), gadget("modFilterString"), gadget("modFilterHidden"), gadget("modFilterVanilla"), gadget("modFilterFolder"))
    
    
    ; register to repository module
    Protected json$, *json
    Protected Dim columns.repository::column(0)
    json$ = ReplaceString("[{'name':'name','width':320},"+
                          "{'name':'author_name','width':100},"+
                          "{'name':'version','width':60}]", "'", #DQUOTE$)
    *json = ParseJSON(#PB_Any, json$)
    ExtractJSONArray(JSONValue(*json), columns())
    FreeJSON(*json)
    
    repository::registerWindow(window)
    repository::registerListGadget(gadget("repoList"), columns())
    repository::registerThumbGadget(gadget("repoPreviewImage"))
    repository::registerFilterGadgets(gadget("repoFilterString"), gadget("repoFilterTypes"), gadget("repoFilterSources"), gadget("repoFilterInstalled"))
    
    repository::init() ; only starts thread -> returns quickly
    
    
    ; apply sizes
    RefreshDialog(dialog)
    resize()
    
    ; init gui texts and button states
    updateModButtons()
    updateRepoButtons()
    
    
    UnuseModule locale
  EndProcedure
  
  Procedure stopGUIupdate(stop = #True)
    _noUpdate = stop
  EndProcedure
  
  Procedure setColumnWidths(Array widths(1))
    Protected i
    For i = 0 To ArraySize(widths())
      If widths(i)
        SetGadgetItemAttribute(gadget("modList"), #PB_Any, #PB_Explorer_ColumnWidth, widths(i), i)
        ; Sorting
        ListIcon::SetColumnFlag(gadget("modList"), i, ListIcon::#String)
      EndIf
    Next
  EndProcedure
  
  Procedure getColumnWidth(column)
    ProcedureReturn GetGadgetItemAttribute(gadget("modList"), #PB_Any, #PB_Explorer_ColumnWidth, column)
  EndProcedure
  
  Structure findModStruct
    source$
    id.q
    fileID.q
  EndStructure
  
  Procedure repoFindModAndDownloadThread(*buffer.findModStruct)
    Protected source$, id.q, fileID.q
    
    source$ = *buffer\source$
    id      = *buffer\id
    fileID  = *buffer\fileID
    FreeStructure(*buffer)
    
    While Not repository::_READY
      ; wait for repository to be loaded before starting download
      Delay(100)
    Wend
    
    If source$ And id
      ; if not fileID and canDownloadMod > 1  ==> show file selection window!
      ; else -> start download
      
      If Not fileID And repository::canDownloadModByID(source$, id) > 1
        Protected *repoMod.repository::mod
        *repoMod = repository::getModByID(source$, id)
        If *repoMod
          ; cannot directly call "repoDownloadShowSelection()" as this procedure is not called in the main thread!
          ; send event to main window to open the selection
          PostEvent(#Event_Repo_Show_Selection, window, 0, #PB_EventType_FirstCustomValue, *repoMod)
        EndIf
      Else
        repository::downloadMod(source$, id, fileID)
      EndIf
    Else
      debugger::add("windowMain::repoFindModAndDownload("+source$+", "+id+", "+fileID+") - ERROR")
    EndIf
    
  EndProcedure
  
  Procedure repoFindModAndDownload(source$, id.q, fileID.q = 0)
    ; search for a mod in repo and initiate download
    
    Protected *buffer.findModStruct
    *buffer = AllocateStructure(findModStruct)
    
    *buffer\source$ = source$
    *buffer\id      = id
    *buffer\fileID  = fileID
    
    ; start in thread in order to wait for repository to finish
    CreateThread(@repoFindModAndDownloadThread(), *buffer)
  EndProcedure
  
  
EndModule