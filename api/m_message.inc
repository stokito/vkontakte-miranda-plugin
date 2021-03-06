{  
  Miranda IM: the free IM client for Microsoft  Windows 
  
  Copyright 2000-2003 Miranda ICQ/IM project, 
  all portions of this codebase are copyrighted to the people 
  listed in contributors.txt.
  
  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
}
{$IFNDEF M_MESSAGE}
{$DEFINE M_MESSAGE}
const
  {brings up the send message dialog for a contact
   wParam=(WPARAM)(HANDLE)hContact
   lParam=(LPARAM)(char*)szText
   returns 0 on success or nonzero on failure
   returns immediately, just after the dialog is shown
   szText is the text to put in the edit box of the window (but not send)
   szText=NULL will not use any text
   szText!=NULL is only supported on v0.1.2.0+
   NB: Current versions of the convers plugin use the name
   "SRMsg/LaunchMessageWindow" instead. For compatibility you should call
   both names and the correct one will work. }
   MS_MSG_SENDMESSAGE = 'SRMsg/SendCommand';
   ME_MSG_WINDOWEVENT = 'MessageAPI/WindowEvent';

  {wparam=0 }
  {lparam=(WPARAM)(MessageWindowEventData*)hWindowEvent; }
  {Event types }
  MSG_WINDOW_EVT_OPENING = 1; // window is about to be opened
  MSG_WINDOW_EVT_OPEN    = 2; // window has been opened
  MSG_WINDOW_EVT_CLOSING = 3; // window is about to be closed
  MSG_WINDOW_EVT_CLOSE   = 4; // window has been closed
  MSG_WINDOW_EVT_CUSTOM  = 5; // custom event for message plugins to use
                              // (custom uFlags may be used)
  MSG_WINDOW_UFLAG_MSG_FROM = $00000001;
  MSG_WINDOW_UFLAG_MSG_TO   = $00000002;
  MSG_WINDOW_UFLAG_MSG_BOTH = $00000004;

type
  PMessageWindowEventData = ^TMessageWindowEventData;
  TMessageWindowEventData = record
    cbSize    : int;
    hContact  : THANDLE;
    hwndWindow: HWND;    // top level window for the contact
    szModule  : Pchar;   // used to get plugin type (which means you could use
                         // local if needed)
    uType     : dword;   // see event types above
    uFlags    : dword;   // used to indicate message direction for all event
                         // types except custom
    local     : pointer; // used to store pointer to custom data
    hwndInput : HWND;    // input area window for the contact (or NULL if there is none)
    hwndLog   : HWND;    // log area window for the contact (or NULL if there is none)
  end;

const
  MS_MSG_GETWINDOWAPI = 'MessageAPI/WindowAPI';
  { wparam=0
    lparam=0
    Returns a dword with the current message api version
    Current version is 0,0,0,4
  }

  MS_MSG_GETWINDOWCLASS = 'MessageAPI/WindowClass';
  { wparam=(char*)szBuf
    lparam=(int)cbSize size of buffer
    Sets the window class name in wParam (ex. "SRMM" for srmm.dll)
  }

type
  PMessageWindowInputData = ^TMessageWindowInputData;
  TMessageWindowInputData = record
    cbSize  : int;
    hContact: THANDLE;
    uFlags  : int; // see uflags above
  end;

const
  MSG_WINDOW_STATE_EXISTS  = $00000001; // Window exists should always be true
                                        // if hwndWindow exists
  MSG_WINDOW_STATE_VISIBLE = $00000002;
  MSG_WINDOW_STATE_FOCUS   = $00000004;
  MSG_WINDOW_STATE_ICONIC  = $00000008;

type
  PMessageWindowOutputData = ^TMessageWindowOutputData;
  TMessageWindowOutputData = record
    cbSize    : int;
    hContact  : THANDLE;
    uFlags    : int;     // should be same as input data unless 0, then it
                         // will be the actual type
    hwndWindow: HWND;    // top level window for the contact or NULL if no window exists
    uState    : int;     // see window states
    local     : pointer; // used to store pointer to custom data
  end;
  PMessageWindowData = PMessageWindowOutputData;
  TMessageWindowData = TMessageWindowOutputData;

const
  MS_MSG_GETWINDOWDATA = 'MessageAPI/GetWindowData';
{ wparam=(MessageWindowInputData*)
  lparam=(MessageWindowOutputData*)
  returns 0 on success and returns non-zero (1) on error or if no window data
  exists for that hcontact
}

  ME_MSG_WINDOWPOPUP = 'MessageAPI/WindowPopupRequested';
{ wParam = 0
 lParam = (MessageWindowPopupData *)&MessageWindowPopupData;
 Fired to allow plugins to add itens to the msg window popup menu
 Always fired twice: once with MSG_WINDOWPOPUP_SHOWING and once with MSG_WINDOWPOPUP_SELECTED.
 This is done to allow cleaning of resources.
}
  MSG_WINDOWPOPUP_SHOWING  = 1;
  MSG_WINDOWPOPUP_SELECTED = 2;

  MSG_WINDOWPOPUP_INPUT = 1;
  MSG_WINDOWPOPUP_LOG   = 2;

type
  MessageWindowPopupData = record
    cbSize   :int;
    uType    :uint;    // see popup types above
    uFlags   :uint;    // used to indicate in which window the popup was requested
    hContact :THANDLE;
    hwnd     :HWND;    // window where the popup was requested
    hMenu    :HMENU;   // The handle to the menu
    pt       :TPOINT;  // The point, in screen coords
    selection:int;     // The menu control id or 0 if no one was selected
  end;

// status icons - HICONs will be automatically destroyed when removed or when miranda exits
const
  MBF_DISABLED = 1;
  MBF_HIDDEN   = 2;

type
  StatusIconData = record
    cbSize       :integer;
    szModule     :PChar;    // used in combo with the dwId below to create a unique identifier
    dwId         :DWORD;
    hIcon,
    hIconDisabled:HICON;    // hIconDisabled is optional - if null, will use hIcon in the disabled state
    flags        :integer;  // one of MBF_* above
    szTooltip    :PChar;
  end;

const
  MBCF_RIGHTBUTTON = 1; // if this flag is specified, the click was a right button -
                        // otherwize it was a left click

type
  StatusIconClickData = record
    cbSize       :integer;
    clickLocation:TPOINT;  // click location, in screen coordinates
    szModule     :PChar;
    dwId         :DWORD;
    flags        :integer;  // one of MBCF_* above
  end;

const
  MS_MSG_ADDICON = 'MessageAPI/AddIcon';
// lParam = (StatusIconData *)&StatusIconData

  MS_MSG_REMOVEICON = 'MessageAPI/RemoveIcon';
{
 lParam = (StatusIconData *)&StatusIconData
 only szModule and szId are used
}

  MS_MSG_MODIFYICON = 'MessageAPI/ModifyIcon';
{
 wParam = (HANDLE)hContact
 lParam = (StatusIconData *)&StatusIconData
 if hContact is null, icon is modified for all contacts
 otherwise, only the flags field is valid
 if either hIcon, hIconDisabled or szTooltip is null, they will not be modified
}

  ME_MSG_ICONPRESSED = 'MessageAPI/IconPressed';
{
 wParam = (HANDLE)hContact;
 lParam = (StatusIconClickData *)&StatusIconClickData;
 catch to show a popup menu, etc.
}
{$ENDIF}
