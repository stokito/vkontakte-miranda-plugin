(*
    VKontakte plugin for Miranda IM: the free IM client for Microsoft Windows

    Copyright (c) 2008-2010 Andrey Lukyanov

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
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*)

{-----------------------------------------------------------------------------
 vk_auth.pas

 [ Description ]
 Module to support authorization process

 [ Known Issues ]
 See the code

 Contributors: LA
-----------------------------------------------------------------------------}
unit vk_auth;

interface

uses
  m_globaldefs,
  m_api,
  Windows;

procedure AuthInit();
procedure AuthDestroy();
procedure vk_AuthRequestSend(ID: integer; MessageText: WideString);
function DlgAuthAsk(Dialog: HWnd; Msg: cardinal; wParam, lParam: DWord): boolean; stdcall;

implementation

uses
  vk_global, // module with global variables and constant used
  vk_http,   // module to connect with the site
  vk_opts,   // unit to work with options
  vk_captcha,
  vk_popup,
  htmlparse, // module to simplify html parsing

  Messages,
  SysUtils,
  Classes;

type
  PAuthRequest = ^TAuthRequest;

  TAuthRequest = record
    ID:          integer;
    MessageText: WideString;
  end;

var
  vk_hAuthRequestSend, vk_hAuthRequestReceived, vk_hAuthRequestReceivedAllow, vk_hAuthRequestReceivedDeny: THandle;

  AuthRequestID: integer; // temp variable to keep ID of contact, whom we are trying to get authorization from

 // =============================================================================
 // function to read Secure ID to request authorization
 // (used only for contacts, which are already in contact list,
 // for search another procedure is used)
 // -----------------------------------------------------------------------------
function vk_GetSecureIDAuthRequest(UserID: integer): string;
var
  HTML: string;
begin
  HTML := HTTP_NL_Get(Format(vk_url + vk_url_auth_securityid, [UserID]));
  Result := TextBetween(HTML, 'id=\"h\" value=\"', '\"');
end;

 // =============================================================================
 // procedure to request authorization
 // TODO: no text of authorization is supported now due to User API restrictions
 // -----------------------------------------------------------------------------
procedure vk_AuthRequestSend(ID: integer; MessageText: WideString);
var
  sHTML: string;
begin
  if vk_userapi_session_id <> '' then
  begin
    sHTML := HTTP_NL_Get(Format(vk_url_uapi + vk_url_userapi_friends_add, [ID, vk_userapi_session_id]));
    if Pos('-', sHTML) = 0 then // successful
    begin
      ShowPopupMsg(0, err_userapi_auth_successful, 1);
    end
    else
      ShowPopupMsg(0, err_userapi_auth_failed, 2);
  end
  else
    ShowPopupMsg(0, err_userapi_session_nodetail_auth, 2);
end;

 // =============================================================================
 // procedure to accept somebody's request to add us to their contact (friend's) list
 // -----------------------------------------------------------------------------
procedure vk_AuthRequestReceivedAllow(ID: string);
var
  HTML:                 string;
  RequestURL:           string;
  sCaptchaValue, sHash: string;
begin
  // first we have to get URL to accept request
  HTML := HTTP_NL_Get(vk_url_pda + vk_url_pda_authrequestreceived_requestid);
  RequestURL := TextBetween(HTML, 'addfriend', '"');
  RequestURL := vk_url_pda + '/addfriend' + RequestURL;

  // GAP (?): we don't care about result as of now
  HTML := HTTP_NL_Get(RequestURL, REQUEST_GET);
  if Pos('captcha', HTML) > 0 then
  begin // captcha input required
    sCaptchaValue := ProcessCaptcha(TextBetween(HTML, 'captcha_sid=', '"'));
    sHash := TextBetween(HTML, 'hash" value="', '"');
    RequestURL := TextBetween(HTML, 'addfriend', '&amp;');
    RequestURL := vk_url_pda + '/addfriend' + RequestURL;
    RequestURL := RequestURL + '&pda=1&hash=' + sHash + '&captcha_key=' + sCaptchaValue;
    HTTP_NL_Get(RequestURL, REQUEST_HEAD);
  end;
end;

 // =============================================================================
 // procedure to deny somebody's request to add us to their contact (friend's) list
 // -----------------------------------------------------------------------------
procedure vk_AuthRequestReceivedDeny(ID: string);
var
  HTML:       string;
  RequestURL: string;
begin
  // first we have to get URL to deny request
  HTML := HTTP_NL_Get(vk_url_pda + vk_url_pda_authrequestreceived_requestid);
  RequestURL := TextBetween(HTML, 'deletefriend', '"');
  RequestURL := vk_url_pda + '/deletefriend' + RequestURL;

  // GAP (?): we don't care about result as of now
  HTTP_NL_Get(RequestURL, REQUEST_HEAD);
end;

 // =============================================================================
 // function is called when user tries to add contact and requests authorization
 // -----------------------------------------------------------------------------
function AuthRequestSend(wParam: wParam; lParam: lParam): integer; cdecl;
var
  ccs_ar: PCCSDATA;
begin
  ccs_ar := PCCSDATA(lParam);
  // GAP (?): use Ansi string as Unicode not supported by Miranda
  // call function to send authorization request
  vk_AuthRequestSend(psreID, PChar(ccs_ar.lParam));
  Result := 0;
end;

 // =============================================================================
 // function to process received authorization request
 // -----------------------------------------------------------------------------
function AuthRequestReceived(wParam: wParam; lParam: lParam): integer; cdecl;
var
  ccs_ar:           PCCSDATA;
  dbeo, dbei:       TDBEVENTINFO; // varibables required to add auth request to Miranda DB
  pre:              TPROTORECVEVENT;
  hEvent, hContact: THandle;
begin
  Netlib_Log(vk_hNetlibUser, PChar('(AuthRequestReceived) New authorization request adding to DB...'));

  ccs_ar := PCCSDATA(lParam);
  pre := PPROTORECVEVENT(ccs_ar.lParam)^;

  // look for presence of the same request in db
  // if here - no need to add the same again
  hEvent := pluginLink^.CallService(MS_DB_EVENT_FINDLAST, 0, 0);
  while hEvent <> 0 do
  begin
    FillChar(dbei, SizeOf(dbei), 0);
    dbei.cbSize := SizeOf(dbei);
    dbei.cbBlob := PluginLink^.CallService(MS_DB_EVENT_GETBLOBSIZE, hEvent, 0);
    dbei.pBlob := AllocMem(dbei.cbBlob);
    PluginLink^.CallService(MS_DB_EVENT_GET, hEvent, Windows.lParam(@dbei));
    Inc(dbei.pBlob, sizeof(DWord)); // skip id
    hContact := PHandle(dbei.pBlob)^;
    if (dbei.szModule = piShortName) and // potential BUG - logic may be incorrect
      (dbei.eventType = EVENTTYPE_AUTHREQUEST) and
      (hContact = ccs_ar^.hContact) then
    begin // duplicate request
      Netlib_Log(vk_hNetlibUser, PChar('(AuthRequestReceived) ... duplicate authorization request'));
      Result := 0;
      Exit;
    end;
    hEvent := pluginLink^.CallService(MS_DB_EVENT_FINDPREV, hEvent, 0);
  end;


  FillChar(dbeo, SizeOf(dbeo), 0);
  with dbeo do
  begin
    cbSize := SizeOf(dbeo);
    eventType := EVENTTYPE_AUTHREQUEST;    // auth request
    szModule := piShortName;
    pBlob := PByte(pre.szMessage);      // data
    cbBlob := pre.lParam;
    flags := 0;
    timestamp := pre.timestamp;
  end;

  PluginLink^.CallService(MS_DB_EVENT_ADD, 0, dword(@dbeo));

  Result := 0;

  Netlib_Log(vk_hNetlibUser, PChar('(AuthRequestReceived) ... finished new authorization request adding to DB'));
end;


 // =============================================================================
 // function is called when somebody is looking for our authorization and
 // we authorize him/her
 // -----------------------------------------------------------------------------
function AuthRequestReceivedAllow(wParam: wParam; lParam: lParam): integer; cdecl;
var
  dbei:     TDBEVENTINFO;
  // nick: PChar;
  hContact: THandle;
begin
  // wParam : HDBEVENT
  // nick, firstname, lastName, e-mail, requestReason: ASCIIZ;
  FillChar(dbei, SizeOf(dbei), 0);
  dbei.cbSize := SizeOf(dbei);
  dbei.cbBlob := PluginLink^.CallService(MS_DB_EVENT_GETBLOBSIZE, wParam, 0);
  dbei.pBlob := AllocMem(dbei.cbBlob);
  PluginLink^.CallService(MS_DB_EVENT_GET, wParam, Windows.lParam(@dbei));

  if (dbei.eventType <> EVENTTYPE_AUTHREQUEST) or // not auth request
    (StrComp(dbei.szModule, piShortName) <> 0) then // not for our plugin
  begin
    Result := 1;
    exit;
  end;

  Inc(dbei.pBlob, sizeof(DWord)); // skip id
  hContact := PHandle(dbei.pBlob)^;

  if hContact <> 0 then
  begin
    // call function to accept authorization on site
    vk_AuthRequestReceivedAllow(IntToStr(DBGetContactSettingDword(hContact, piShortName, 'ID', 0)));
    // immediately add contact to our list (really we just show hidden contact)
    DBWriteContactSettingByte(hContact, 'CList', 'NotOnList', 0);
    DBWriteContactSettingByte(hContact, 'CList', 'Hidden', 0);
  end;

  Result := 0;
end;

 // =============================================================================
 // function is called when somebody is looking for our authorization and
 // we DON'T authorize him/her
 // -----------------------------------------------------------------------------
function AuthRequestReceivedDeny(wParam: wParam; lParam: lParam): integer; cdecl;
var
  dbei:     TDBEVENTINFO;
  hContact: THandle;
begin
  // wParam : HDBEVENT
  // nick, firstname, lastName, e-mail, requestReason: ASCIIZ;
  FillChar(dbei, SizeOf(dbei), 0);
  dbei.cbSize := SizeOf(dbei);
  dbei.cbBlob := PluginLink^.CallService(MS_DB_EVENT_GETBLOBSIZE, wParam, 0);
  dbei.pBlob := AllocMem(dbei.cbBlob);
  PluginLink^.CallService(MS_DB_EVENT_GET, wParam, Windows.lParam(@dbei));

  if (dbei.eventType <> EVENTTYPE_AUTHREQUEST) or // not auth request
    (StrComp(dbei.szModule, piShortName) <> 0) then // not for our plugin
  begin
    Result := 1;
    exit;
  end;

  Inc(dbei.pBlob, sizeof(DWord)); // skip id
  hContact := PHandle(dbei.pBlob)^;

  if hContact <> 0 then
    // call function to deny authorization on site
    vk_AuthRequestReceivedDeny(IntToStr(DBGetContactSettingDword(hContact, piShortName, 'ID', 0)));

  Result := 0;
end;

 // =============================================================================
 // procedure to request authorization from our own dialog
 // - run in a separate thread
 // -----------------------------------------------------------------------------
procedure AuthAsk(AuthRequest: PAuthRequest);
begin
  vk_AuthRequestSend(AuthRequest^.ID, AuthRequest^.MessageText);
  Dispose(AuthRequest);
end;

 // =============================================================================
 // Dialog function to ask Auth request text
 // -----------------------------------------------------------------------------
function DlgAuthAsk(Dialog: HWnd; Msg: cardinal; wParam, lParam: DWord): boolean; stdcall;
var
  str:         WideString;   // temp variable for types conversion
  pc:          PWideChar;    // temp variable for types conversion
  res:         longword;
  AuthRequest: PAuthRequest;
begin
  Result := False;
  case Msg of
    WM_INITDIALOG:
    begin
      // translate all dialog texts
      TranslateDialogDefault(Dialog);
      AuthRequestID := DBGetContactSettingDWord(lParam, piShortName, 'ID', 0);
      SetFocus(GetDlgItem(Dialog, VK_AUTH_TEXT));
    end;
    WM_CLOSE:
    begin
      EndDialog(Dialog, 0);
      Result := True;
    end;
    WM_COMMAND:
    begin
      case wParam of
        VK_AUTH_OK:
        begin
          SetLength(Str, 2048);
          pc := PWideChar(Str);
          GetDlgItemTextW(Dialog, VK_AUTH_TEXT, pc, 2048);
          New(AuthRequest);
          AuthRequest^.MessageText := pc;
          AuthRequest^.ID := AuthRequestID;
          // request authorization in a separate thread
          if AuthRequest.ID <> 0 then
            CloseHandle(BeginThread(nil, 0, @AuthAsk, AuthRequest, 0, res));
          EndDialog(Dialog, 0);
          Result := True;
        end;
        VK_AUTH_CANCEL:
        begin
          EndDialog(Dialog, 0);
          Result := True;
        end;
      end;
    end;
  end;
end;


 // =============================================================================
 // function to initiate authorization process support
 // -----------------------------------------------------------------------------
procedure AuthInit();
begin
  vk_hAuthRequestSend := CreateProtoServiceFunction(piShortName, PSS_AUTHREQUEST, AuthRequestSend);
  vk_hAuthRequestReceived := CreateProtoServiceFunction(piShortName, PSR_AUTH, AuthRequestReceived);
  vk_hAuthRequestReceivedAllow := CreateProtoServiceFunction(piShortName, PS_AUTHALLOW, AuthRequestReceivedAllow);
  vk_hAuthRequestReceivedDeny := CreateProtoServiceFunction(piShortName, PS_AUTHDENY, AuthRequestReceivedDeny);
end;

 // =============================================================================
 // function to destroy authorization process support
 // -----------------------------------------------------------------------------
procedure AuthDestroy();
begin
  pluginLink^.DestroyServiceFunction(vk_hAuthRequestSend);
  pluginLink^.DestroyServiceFunction(vk_hAuthRequestReceived);
  pluginLink^.DestroyServiceFunction(vk_hAuthRequestReceivedAllow);
  pluginLink^.DestroyServiceFunction(vk_hAuthRequestReceivedDeny);
end;


begin
end.
