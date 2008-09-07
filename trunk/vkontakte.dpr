// MessageBox(0, 'Just groovy, baby!', 'Plugin-o-rama', MB_OK);
library vkontakte;

uses
  m_globaldefs in 'api\m_globaldefs.pas',
  m_api in 'api\m_api.pas',

  vk_global, // module with global variables and constant used
  vk_http, // module to connect with the site
  vk_menu, // module to work with menus
  vk_auth, // module to support authorization process
  vk_avatars, // module to support avatars
  vk_xstatus, // module to support additional status
  vk_info, // module to get contact's info
  vk_folders, // module to support custom folders
  vk_msgs, // module to send/receive messages
  vk_core, // module with core functions

  vk_opts,

  Windows,
  SysUtils,

  uLkJSON in 'inc\uLkJSON.pas';

const

  // constants to provide information about plugin
  // values defined in vk_opts
  PluginInfoEx: TPLUGININFOEX = (
    cbSize: SizeOf(TPLUGININFOEX);
    shortName: piShortName;
    version: piVersion;
    description: piDescription;
    author: piAuthor;
    authorEmail: piAuthorEmail;
    copyright: piCopyright;
    homepage: piHomepage;
    // flags: UNICODE_AWARE;
    flags: 0;
    replacesDefaultModule: 0;
    uuid: '{75A5596C-3AD4-4B17-ABEF-5D45DEAA4A83}'
  );

  PluginInfo: TPLUGININFO = (
    cbSize: SizeOf(TPLUGININFO);
    shortName: piShortName;
    version: piVersion;
    description: piDescription;
    author: piAuthor;
    authorEmail: piAuthorEmail;
    copyright: piCopyright;
    homepage: piHomepage;
    // flags: UNICODE_AWARE;
    flags: 0;
    replacesDefaultModule: 0;
  );


var

  timer_keeponline,
  timer_friendsstatus,

  vk_hGetCaps,
  vk_hGetName,
  vk_hGetStatus,
  vk_hSetStatus,
  vk_hLoadIcon,
  vk_hBasicSearch,
  vk_hAddToList,


  vk_hkContactDeleted,
  vk_hkModulesLoad,
  vk_hkOptInitialise: THandle;


  // ccs: PCCSDATA;

  PluginInterfaces:array [0..1] of MUUID;

// =============================================================================
// functions to provide information about plugin
// -----------------------------------------------------------------------------
function MirandaPluginInfo(mirandaVersion: DWORD): PPLUGININFO; cdecl;
begin
  Result := @PluginInfo;
end;

function MirandaPluginInfoEx(mirandaVersion:DWORD): PPLUGININFOEX; cdecl;
begin
  Result := @PluginInfoEx;
end;

function MirandaPluginInterfaces:PMUUID; cdecl;
begin
  PluginInterfaces[0] := PluginInfoEx.uuid;
  PluginInterfaces[1] := MIID_LAST;
  result := @PluginInterfaces;
end;

// declaration of the function, which will be defined later
function OnModulesLoad(wParam,lParam:DWord): Integer; cdecl; forward;

// =============================================================================
// function to identify list of functions supported by the plugin
// -----------------------------------------------------------------------------
function GetCaps(wParam: wParam; lParam: lParam): Integer; cdecl;
begin
  Case wParam Of
    PFLAGNUM_1:
      Result := PF1_SEARCHBYNAME or // protocol supports searching by nick/first/last names
      PF1_IM or // supports IM sending & receiving
      PFLAGNUM_1 or // will get authorisation requests for some or all contacts
      // PF1_NUMERICUSERID; // the unique user IDs for this protocol are numeric
      PF1_SERVERCLIST; // contact lists are stored on the server, not locally

    PFLAGNUM_2:
      Result := PF2_ONLINE or PF2_INVISIBLE; // list of statuses supported, just online & offline is required

    // PFLAGNUM_3 :
    // Result := PF2_ONLINE or PF2_LONGAWAY;

   PFLAGNUM_4:
      Result := $00000100 or // PF4_IMSENDOFFLINE; protocol is able to send offline messages
                PF4_AVATARS; // avatars supported

   PFLAG_UNIQUEIDTEXT:
     Result := Integer(Translate('ID')); // returns a static buffer of text describing the unique field by which this protocol identifies users
                                         // this name will be used for ex. in BASIC SEARCH

    PFLAG_MAXLENOFMESSAGE:
      Result := 2000;  // maximum length of one message

    PFLAG_UNIQUEIDSETTING:
      Result := Integer(PChar('ID')); // returns the DB setting name that has the ID which makes this user unique on that system
  Else
    Result := 0;
  End;
end;

// =============================================================================
// function to copy the name of the protocole into lParam
// -----------------------------------------------------------------------------
function GetName(wParam: wParam; lParam: lParam): Integer; cdecl;
begin
  StrLCopy(PChar(lParam), piShortName, wParam);
  Result := 0;
end;


// =============================================================================
// function to change the status and notifies everybody
// -----------------------------------------------------------------------------
function SetStatus(wParam: wParam; lParam: lParam): Integer; cdecl;
begin
  if wParam = vk_Status then
  begin
     result := 0;
     exit;
  end;
  vk_StatusPrevious := vk_Status;
  vk_Status := wParam;
  // we don't support all statuses, but Miranda may try to
  // setup unsupported status (for ex., when user presses Ctrl+0..9
  // so, we should have the following line
  if (vk_Status = ID_STATUS_AWAY) or
     (vk_Status = ID_STATUS_DND) or
     (vk_Status = ID_STATUS_NA) or
     (vk_Status = ID_STATUS_OCCUPIED) or
     (vk_Status = ID_STATUS_FREECHAT) or
     (vk_Status = ID_STATUS_ONTHEPHONE) or
     (vk_Status = ID_STATUS_OUTTOLUNCH) then
   begin
     vk_Status := ID_STATUS_ONLINE;
   end;

  if not Assigned(ThrIDConnect) then
    ThrIDConnect := TThreadConnect.Create(False); // initiate new thread for connection

  Result := 0;
end;

// =============================================================================
// function to return the current status
// -----------------------------------------------------------------------------
function GetStatus(wParam: wParam; lParam: lParam): Integer; cdecl;
begin
  Result := vk_Status;
end;

// =============================================================================
// function loads
// the icon corresponding to the status
// called by the CList when the status changes.
// wParam: one of the following values:
// PLI_PROTOCOL | PLI_ONLINE | PLI_OFFLINE
// returns an HICON in which the icon has been loaded
// -----------------------------------------------------------------------------
function LoadIcon (wParam: wParam; lParam: lParam): Integer; cdecl;
var
  id: string; // to store id of icon to be loaded
  cx: int;
  cy: int;
begin
  // regardless of the code below, this function is called only when
  // wParam = PLI_PROTOCOL and it is required to display proto icon
  // in Miranda's main menu -> Status

  case (wParam and $ffff) of
      PLI_PROTOCOL: id := 'ICON_PROTO'; // icon representing protocol
      PLI_ONLINE: id := 'ICON_ONLINE'; // online state icon for the protocol
      PLI_OFFLINE: id := 'ICON_OFFLINE'; // offline state icon for the protocol
    else
      Result := 0;
      Exit;
  end;

 if (bool(wParam and PLIF_SMALL)) then
    begin
      // if small icon - 16x16 by default
      cx := SM_CXSMICON;
      cy := SM_CYSMICON;
    end
    else
    begin
      // if big icon - 32x32 by default
      cx := SM_CXICON;
      cy := SM_CYICON
    end;

// Result := LoadImage(hInstance, MAKEINTRESOURCE('ICON_PROTO'), IMAGE_ICON, 16, 16, 0);
// Result := PluginLink^.CallService(MS_SKIN2_GETICON, 0, Windows.lparam(vk_icon_note));
// Result := LoadSkinnedIcon(SKINICON_OTHER_MIRANDA);
// Result := CopyIcon(CallService(MS_SKIN2_GETICONBYHANDLE, 0, (LPARAM)iconList[i].hIconLibItem));

  Result := Int(LoadImage(hInstance,
  MAKEINTRESOURCE(PChar(id)),
  IMAGE_ICON,
  GetSystemMetrics(cx),
  GetSystemMetrics(cy),
  0));
end;

// =============================================================================
// function identifies what should be done when plugin is being loaded
// -----------------------------------------------------------------------------
function Load(link: PPLUGINLINK): integer; cdecl;
var
  pd: TPROTOCOLDESCRIPTOR;
begin
  // the following two lines are VERY VERY important, if it's not present, expect crashes
  pluginLink := Pointer(link);
  InitMMI;

  // register new protocol
  FillChar(pd, sizeof(pd), 0);
  pd.cbSize := sizeof(pd);
  pd.szName := piShortName;
  pd._type := PROTOTYPE_PROTOCOL;
  pluginLink^.CallService(MS_PROTO_REGISTERMODULE, 0, lParam(@pd));

  // register additional services required for protocol
  vk_hGetCaps := CreateProtoServiceFunction(piShortName, PS_GETCAPS, GetCaps);
  vk_hGetName := CreateProtoServiceFunction(piShortName, PS_GETNAME, GetName);
  vk_hSetStatus := CreateProtoServiceFunction(piShortName, PS_SETSTATUS, SetStatus);
  vk_hGetStatus := CreateProtoServiceFunction(piShortName, PS_GETSTATUS, GetStatus);
  vk_hLoadIcon := CreateProtoServiceFunction(piShortName, PS_LOADICON, LoadIcon);

  // register functions required to send and receive messages
  MsgsInit();

  vk_hBasicSearch := CreateProtoServiceFunction(piShortName, PS_SEARCHBYNAME, SearchByName);
  vk_hAddToList := CreateProtoServiceFunction(piShortName, PS_ADDTOLIST, AddToList);

  AuthInit();

  InfoInit();

  SetStatusOffline(); // make all contacts offline

  // hook event when contact is deleted & delete contact from Friends list on the server
  vk_hkContactDeleted := pluginLink^.HookEvent(ME_DB_CONTACT_DELETED, @ContactDeleted);

  //identifies the function OnModulesLoad(), which will be run once all
  //modules are loaded
  vk_hkModulesLoad := pluginLink^.HookEvent(ME_SYSTEM_MODULESLOADED, @OnModulesLoad);

  Result := 0;
end;

// =============================================================================
// function, which run once all modules are loaded
// -----------------------------------------------------------------------------
function OnModulesLoad(wParam{0}, lParam{0}: DWord): Integer; cdecl;
begin
  // code to identify Options function
  vk_hkOptInitialise := pluginLink^.HookEvent(ME_OPT_INITIALISE, @OnOptInitialise);

  // updater compatibility data
  if PluginLink^.ServiceExists(MS_UPDATE_REGISTER)<>0 then
  begin
    // 3730 - id of the plugin on addons.miranda-im.org - http://addons.miranda-im.org/details.php?action=viewfile&id=3730
    PluginLink^.CallService(MS_UPDATE_REGISTERFL, 3730, Windows.lParam(@PluginInfo));
  end;

  //set timers for regular online checking...
  timer_keeponline := SetTimer(0, 0, DBGetContactSettingDWord(0, piShortName, opt_UserKeepOnline, 360)*1000, @TimerKeepOnline);
  timer_friendsstatus := SetTimer(0, 0, DBGetContactSettingDWord(0, piShortName, opt_UserUpdateFriendsStatus, 60)*1000, @TimerUpdateFriendsStatus);

  MenuInit();

  // initiate Additional Status support
  AddlStatusInit();

  // initiate internet connection
  HTTP_NL_Init();

  // register avatars folder for Folders plugin
  FoldersInit();

  AvatarsInit();

  // start regular news checking
  NewsInit();

  Result:=0;
end;

// =============================================================================
// function is run, when plugin is stopped
// -----------------------------------------------------------------------------
function Unload: int; cdecl;
begin
  // kill timers
  KillTimer(0, timer_keeponline);
  KillTimer(0, timer_friendsstatus);

  // wait for threads completion
  If Assigned(ThrIDConnect) Then
    WaitForSingleObject(ThrIDConnect.Handle, 5000);
  If Assigned(ThrIDGetFriends) Then
    WaitForSingleObject(ThrIDGetFriends.Handle, 3000);
  If Assigned(ThrIDKeepOnline) Then
    WaitForSingleObject(ThrIDKeepOnline.Handle, 3000);

  // destroy services
  pluginLink^.DestroyServiceFunction(vk_hGetCaps);
  pluginLink^.DestroyServiceFunction(vk_hGetName);
  pluginLink^.DestroyServiceFunction(vk_hGetStatus);
  pluginLink^.DestroyServiceFunction(vk_hSetStatus);
  pluginLink^.DestroyServiceFunction(vk_hLoadIcon);
  pluginLink^.DestroyServiceFunction(vk_hBasicSearch);
  pluginLink^.DestroyServiceFunction(vk_hAddToList);
  pluginLink^.DestroyServiceFunction(vk_hNetlibUser);

  MsgsDestroy();

  AvatarsDestroy();

  FoldersDestroy();

  AddlStatusDestroy();

  // unhook all events we hooked
  pluginLink^.UnhookEvent(vk_hkContactDeleted);
  pluginLink^.UnhookEvent(vk_hkModulesLoad);
  pluginLink^.UnhookEvent(vk_hkOptInitialise);

  Result := 0;
end;

exports
  MirandaPluginInfo, Load, Unload,
  MirandaPluginInterfaces, MirandaPluginInfoEx;

begin
end.
