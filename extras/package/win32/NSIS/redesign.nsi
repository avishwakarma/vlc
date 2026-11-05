; NSIS installer for "VLC Redesign (unofficial)" (win64).
;
; A separate, small script on purpose: it never touches the registry keys,
; ProgIDs, install directory or Start menu folder of an official VLC
; installation, so both can be installed side by side.
;
; makensis -DVERSION=<x.y.z> -DSRCDIR=<installed vlc tree> -DOUTFILE=<setup.exe> \
;          -DUNINSTLIST=<uninstall.nsh> redesign.nsi
; (extras/package/redesign-ci/win64-package.sh generates UNINSTLIST)

Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel admin

!ifndef VERSION
  !error "VERSION is not defined"
!endif
!ifndef SRCDIR
  !error "SRCDIR is not defined"
!endif
!ifndef OUTFILE
  !define OUTFILE "VLC-Redesign-unofficial-win64-setup.exe"
!endif

!define PRODUCT_NAME "VLC Redesign (unofficial)"
!define PRODUCT_PUBLISHER "VLC Redesign (unofficial) project"
!define PRODUCT_WEB_SITE "https://github.com/avishwakarma/vlc"
!define PRODUCT_KEY "Software\VLC Redesign (unofficial)"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\VLCRedesignUnofficial"
!define CLIENT_KEY "Software\Clients\Media\VLCRedesignUnofficial"
!define PROGID_PREFIX "VLCRedesignUnofficial"

Name "${PRODUCT_NAME}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\${PRODUCT_NAME}"
InstallDirRegKey HKLM "${PRODUCT_KEY}" "InstallDir"
BrandingText "${PRODUCT_NAME} ${VERSION}"
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "4.0.0.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey "FileDescription" "${PRODUCT_NAME} installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "VLC: VideoLAN and VLC authors (GPLv2+). Design by Juxtopposed."

!include "MUI2.nsh"
!include "x64.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON "${SRCDIR}\vlc-redesign.ico"
!define MUI_UNICON "${SRCDIR}\vlc-redesign.ico"
!define MUI_WELCOMEPAGE_TITLE "${PRODUCT_NAME}"
!define MUI_WELCOMEPAGE_TEXT "This installs ${PRODUCT_NAME} ${VERSION}, a redesigned interface for VLC media player.$\r$\n$\r$\nBased on VLC media player by VideoLAN (GPLv2+). Design by Juxtopposed. Unofficial, not affiliated with VideoLAN.$\r$\n$\r$\nIt keeps its own settings and library and can be installed next to the official VLC."
!define MUI_FINISHPAGE_RUN "$INSTDIR\vlc.exe"
!define MUI_FINISHPAGE_LINK "${PRODUCT_WEB_SITE}"
!define MUI_FINISHPAGE_LINK_LOCATION "${PRODUCT_WEB_SITE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${SRCDIR}\COPYING.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

; ProgID + "Open with" entry for one extension; never changes the default handler
!macro RegisterExt EXT KIND
  WriteRegStr HKLM "Software\Classes\${PROGID_PREFIX}.${EXT}" "" "${KIND} (${PRODUCT_NAME})"
  WriteRegStr HKLM "Software\Classes\${PROGID_PREFIX}.${EXT}\DefaultIcon" "" '"$INSTDIR\vlc.exe",0'
  WriteRegStr HKLM "Software\Classes\${PROGID_PREFIX}.${EXT}\shell\open\command" "" '"$INSTDIR\vlc.exe" --started-from-file "%1"'
  WriteRegStr HKLM "Software\Classes\.${EXT}\OpenWithProgids" "${PROGID_PREFIX}.${EXT}" ""
  WriteRegStr HKLM "${CLIENT_KEY}\Capabilities\FileAssociations" ".${EXT}" "${PROGID_PREFIX}.${EXT}"
!macroend
!macro UnregisterExt EXT KIND
  DeleteRegKey HKLM "Software\Classes\${PROGID_PREFIX}.${EXT}"
  DeleteRegValue HKLM "Software\Classes\.${EXT}\OpenWithProgids" "${PROGID_PREFIX}.${EXT}"
!macroend
!macro ForEachExt M
  !insertmacro ${M} "mp4" "Video"
  !insertmacro ${M} "m4v" "Video"
  !insertmacro ${M} "mkv" "Video"
  !insertmacro ${M} "webm" "Video"
  !insertmacro ${M} "avi" "Video"
  !insertmacro ${M} "mov" "Video"
  !insertmacro ${M} "wmv" "Video"
  !insertmacro ${M} "flv" "Video"
  !insertmacro ${M} "mpg" "Video"
  !insertmacro ${M} "mpeg" "Video"
  !insertmacro ${M} "ts" "Video"
  !insertmacro ${M} "m2ts" "Video"
  !insertmacro ${M} "3gp" "Video"
  !insertmacro ${M} "ogv" "Video"
  !insertmacro ${M} "mp3" "Audio"
  !insertmacro ${M} "m4a" "Audio"
  !insertmacro ${M} "aac" "Audio"
  !insertmacro ${M} "flac" "Audio"
  !insertmacro ${M} "ogg" "Audio"
  !insertmacro ${M} "opus" "Audio"
  !insertmacro ${M} "wav" "Audio"
  !insertmacro ${M} "wma" "Audio"
  !insertmacro ${M} "mka" "Audio"
  !insertmacro ${M} "aiff" "Audio"
  !insertmacro ${M} "m3u" "Playlist"
  !insertmacro ${M} "m3u8" "Playlist"
  !insertmacro ${M} "pls" "Playlist"
  !insertmacro ${M} "xspf" "Playlist"
!macroend

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "${PRODUCT_NAME} requires 64-bit Windows 10 or later."
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd

Function un.onInit
  SetRegView 64
FunctionEnd

Section "!${PRODUCT_NAME}" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  File /r "${SRCDIR}\*.*"
  ; plugin cache, as the official installer does
  nsExec::ExecToStack '"$INSTDIR\vlc-cache-gen.exe" "$INSTDIR\plugins"'

  WriteRegStr HKLM "${PRODUCT_KEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "${PRODUCT_KEY}" "Version" "${VERSION}"

  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\vlc.exe,0"
  WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKLM "${UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1

  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}.lnk" "$INSTDIR\vlc.exe" "" "$INSTDIR\vlc.exe" 0
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortCut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\vlc.exe" "" "$INSTDIR\vlc.exe" 0
SectionEnd

Section "Offer in Open with and Default apps" SecAssoc
  ; Registered as a choice only: Windows asks the user before switching defaults.
  WriteRegStr HKLM "Software\RegisteredApplications" "${PRODUCT_NAME}" "${CLIENT_KEY}\Capabilities"
  WriteRegStr HKLM "${CLIENT_KEY}" "" "${PRODUCT_NAME}"
  WriteRegStr HKLM "${CLIENT_KEY}\Capabilities" "ApplicationName" "${PRODUCT_NAME}"
  WriteRegStr HKLM "${CLIENT_KEY}\Capabilities" "ApplicationDescription" "Redesigned VLC media player (unofficial)"
  WriteRegStr HKLM "${CLIENT_KEY}\Capabilities" "ApplicationIcon" "$INSTDIR\vlc.exe,0"
  !insertmacro ForEachExt RegisterExt
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
SectionEnd

LangString DESC_SecMain ${LANG_ENGLISH} "The player and its plugins."
LangString DESC_SecDesktop ${LANG_ENGLISH} "Add a shortcut on the desktop."
LangString DESC_SecAssoc ${LANG_ENGLISH} "List ${PRODUCT_NAME} in Open with and in Settings > Default apps. Does not take over files from VLC or other players."
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} $(DESC_SecMain)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} $(DESC_SecDesktop)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecAssoc} $(DESC_SecAssoc)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  !insertmacro ForEachExt UnregisterExt
  DeleteRegValue HKLM "Software\RegisteredApplications" "${PRODUCT_NAME}"
  DeleteRegKey HKLM "${CLIENT_KEY}"
  DeleteRegKey HKLM "${UNINST_KEY}"
  DeleteRegKey HKLM "${PRODUCT_KEY}"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}.lnk"
  Delete "$DESKTOP\${PRODUCT_NAME}.lnk"

  ; Only the files this installer put there (list generated at build time)
!ifdef UNINSTLIST
  !include "${UNINSTLIST}"
!endif
  Delete "$INSTDIR\plugins\plugins.dat"
  RMDir "$INSTDIR\plugins"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
  ; User settings in %APPDATA%\vlc-redesign are kept.
SectionEnd
