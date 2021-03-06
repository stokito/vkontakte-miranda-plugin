{$IFNDEF M_UTILS}
{$DEFINE M_UTILS}

const
  RD_ANCHORX_CUSTOM = 0; // function did everything required to the x axis, do no more processing
  RD_ANCHORX_LEFT   = 0; // move the control to keep it constant distance from the left edge of the dialog
  RD_ANCHORX_RIGHT  = 1; // move the control to keep it constant distance from the right edge of the dialog
  RD_ANCHORX_WIDTH  = 2; // size the control to keep it constant distance from both edges of the dialog
  RD_ANCHORX_CENTRE = 4; // move the control to keep it constant distance from the centre of the dialog
  RD_ANCHORY_CUSTOM = 0;
  RD_ANCHORY_TOP    = 0;
  RD_ANCHORY_BOTTOM = 8;
  RD_ANCHORY_HEIGHT = 16;
  RD_ANCHORY_CENTRE = 32;

  // for MS_UTILS_RESTOREWINDOWPOSITION
  RWPF_NOSIZE     = 1; // don't use stored size info: leave dialog same size
  RWPF_NOMOVE     = 2; // don't use stored position
  RWPF_NOACTIVATE = 4; // show but don't activate v0.3.3.0+

  // for WNDCLASS_COLOURPICKER
  CPM_SETCOLOUR        = $1000;// lParam=new colour
  CPM_GETCOLOUR        = $1001;// returns colour
  CPM_SETDEFAULTCOLOUR = $1002;// lParam=default, used as first custom colour
  CPM_GETDEFAULTCOLOUR = $1003;// returns colour
  CPN_COLOURCHANGED    = 1;  // sent through WM_COMMAND

  //  Colour picker control, see CPM_* and CPN_* constants above
  WNDCLASS_COLOURPICKER = 'ColourPicker';

  // hyperlink messages
  {
    Use this in a SendMessage to set the color of the url when control is enabled
    wParam=DWORD color
    lParam=not used
  }
  HLK_SETENABLECOLOUR = WM_USER+101; // added in 0.3.1

  {
    Use this in a SendMessage to set the color of the url when control is disabled
    wParam=DWORD color
    lParam=not used
  }
  HLK_SETDISABLECOLOUR = WM_USER+102; // added in 0.3.1

type
  PUTILRESIZECONTROL = ^TUTILRESIZECONTROL;
  TUTILRESIZECONTROL = record
    cbSize         : int;
    wId            : int;   // control ID
    rcItem         : TRECT; // original control rectangle, relative to dialog
                            // modify in-placee to specify the new position
    dlgOriginalSize: TSize; // size of dialog client area in template
    dlgNewSize     : TSize; // current size of dialog client area
  end;

  TDIALOGRESIZERPROC = function(hwndDlg: THANDLE; lParam: LPARAM; urc: PUTILRESIZECONTROL): int; cdecl;

  PUTILRESIZEDIALOG = ^TUTILRESIZEDIALOG;
  TUTILRESIZEDIALOG = record
    cbSize    : int;
    hwndDlg   : HWND;
    hInstance : THANDLE;
    lpTemplate: PAnsiChar;
    lParam    : LPARAM;
    pfnResizer: TDIALOGRESIZERPROC;
  end;

  PCountryListEntry = ^TCountryListEntry;
  TCountryListEntry = record
    id    : int;
    szName: PAnsiChar;
  end;

  PWINDOWLISTENTRY = ^TWINDOWLISTENTRY;
  TWINDOWLISTENTRY = record
    hList   : THANDLE;
    hWnd    : HWND;
    hContact: THANDLE;
  end;

  PSAVEWINDOWPOS = ^TSAVEWINDOWPOS;
  TSAVEWINDOWPOS = record
    hWnd        : HWND;
    hContact    : THANDLE;
    szModule    : PAnsiChar;        // module name eto store the settings in
    szNamePrefix: PAnsiChar;        // text to prefix on 'x', 'width', etc
  end;

const
  {
    wParam : bOpenInNewWindow
    lParam : Pointer to a null terminated string containing Url
    Affect : Open a URRL in the user's default web browser, see notes
    Returns: 0 on success, [non zero on failure]
    Notes  : bOpenInWindow should be zero to open the URL in the browoser window
             the user last used, or nonzero to open in a new browser window,
             if there's no browser running, it will be started to show the URL
    Version: v0.1.0.1+
  }
  MS_UTILS_OPENURL:PAnsiChar = 'Utils/OpenURL';

  {
    wParam : 0
    lParam : Pointer to an initalised TUTILRESIZEDIALOG structure
    Affect : Resize a dialog by calling a custom routine to move each control, see notes
    Returns: 0 on success, [non zero] on failure
    Notes  : Does not support DIALOGTEMPLATEEX dialogboxes, and will return
             failure if you try to resize one.-
             the dialog iteself should have been resized prior to calling this
             service, .pfnResizer is called once for each control in the dialog
             .pfnResizer should return a combination of one RD_ANCHORx_ and one RD_ANCHORy constant
    Version: v0.1.0.1+
  }
  MS_UTILS_RESIZEDIALOG:PAnsiChar = 'Utils/ResizeDialog';

  {
    wParam : countryID
    lParam : 0
    Affect : Get the name of a country given it's number, e.g. 44 = UK
    Returns: Returns a pointer to a string containing the country name on success
             NULL(0) on failure
    Version: v0.1.2.0+
  }
  MS_UTILS_GETCOUNTRYBYNUMBER:PAnsiChar = 'Utils/GetCountryByNumber';

  {
    wParam : Pointer to an int to be filled with count  -- !TODO! test.
    lParam : Pointer to an PCountryListEntry, see notes
    Affect : Get the full list of country IDs, see notes
    Returns: 0 always
    Notes  : the list is sorted alphabetically by name, on the assumption
             it's quicker to search numbers that are out of outer, than strings
             that are out of order. a NULL(0) entry terminates
             -
             Neither wParam or lParam can be NULL(0)
             -
             lParam is filled with the first entry, it can be accessed as a pointer,
             to get the next entry, increment the pointer by sizeof(Pointer) NOT
             sizeof(TCountryList), only increment the pointer as many times as
             given by iCount.
             -
             this data can NOT be copied if an array of TCountryListEntry's is passed
             so don't try it.
    Version: v0.1.2.0+
  }
  MS_UTILS_GETCOUNTRYLIST:PAnsiChar = 'Utils/GetCountryList';

  // see WindowList_* functions below

  {
    wParam : 0
    lParam : 0
    Affect : Allocate a window list
    Returns: A handle to the new window list
    Version: v0.1.0.1+
  }
  MS_UTILS_ALLOCWINDOWLIST:PAnsiChar = 'Utils/AllocWindowList';

  {
    wParam : 0
    lParam : Pointer to an initalised TWINDOWLISTENTRY structure
    Affect : Add a window to a given window list handle
    Returns: 0 on success, [non zero] on failure
    Version: v0.1.0.1+
  }
  MS_UTILS_ADDTOWINDOWLIST:PAnsiChar = 'Utils/AddToWindowList';

  {
    wParam : Handle to window list to remove from
    lParam : Window handle to remove
    Affect : Remove a window from the specified window list
    Returns: 0 on success, [non zero] on failure
    Version: v0.1.0.1+
  }
  MS_UTILS_REMOVEFROMWINDOWLIST:PAnsiChar = 'Utils/RemoveFromWindowList';

  {
    wParam : Handle to the window list to look in
    lParam : Handle to a HCONTACT to find in the window list
    Affect : Find a window handle given the hContact
    Returns: The found window handle or NULL(0) on failure
    Version: v0.1.0.1+
  }
  MS_UTILS_FINDWINDOWINLIST:PAnsiChar = 'Utils/FindWindowInList';

  {
    wParam : Handle to window list
    lParam : Pointer to TMSG (initalised with what to broadcast)
    Affect : Broadcast a message to all windows in a list, see notes
    Returns: 0 on success, [non zero] on failure
    Notes  : only TMSG.Message, .wParam, .lParam are used
    Version: v0.1.0.1+
  }
  MS_UTILS_BROADCASTTOWINDOWLIST:PAnsiChar = 'Utils/BroadcastToWindowList';

  {
  Version: 0.3.0.0+
  Inline helper: WindowList_BroadcastAsync
  wParam : Handle to window list
  lParam : Pointer to TMSG (initalised with what to broadcast)
  Affect : Broadcast a message to all windows in the given list using PostMessage()
  Returns: 0 on success, nonzero on failure, this service does not fail,
           even if PostMessage() fails for whatever reason
  }
  MS_UTILS_BROADCASTTOWINDOWLIST_ASYNC:PAnsiChar = 'Utils/BroadcastToWindowListAsync';

  {
    There aren't any services here, there's no need for them, the control class
    will obey the SS_LEFT (0), SS_CENTER (1), SS_RIGHT(2) styles
    the control will send STN_CLICKED via WM_COMMAND when the link itself is clicked
    -
    These are defined by STATIC controls and STN_CLICKED is sent to standard
    STATIC classes when they're clicked -- look at WINAPI docs for more info
  }
  WNDCLASS_HYPERLINK = 'Hyperlink';

  {
    wParam : 0
    lParam : Pointer to a initialised TSAVEWINDOWPOS structure
    Affect :
    Returns: 0 on success, [non zero] on failure
    Notes  :
    Version: v0.1.1.0+
  }
  MS_UTILS_SAVEWINDOWPOSITION:PAnsiChar = 'Utils/SaveWindowPos';

  {
    wParam : see RWPF_* flags
    lParam : Pointer to a initalised TSAVEWINDOWPOS
    Affect : Restores the position of a window from the database, see notes
    Returns: 0 on success, [non zero] on failure
    Notes  : If no position info was found, the service will return 1.
             The NoSize version won't use stored information size, the window
             is left the same size
             -
             See Utils_RestoreWindowPosition() Helper function, this function is
             a bit different from the C function (which can be inlined too! dammit)
             that there's only one function and not three (which just passed different flags)
    Version: v0.1.1.0+
  }
  MS_UTILS_RESTOREWINDOWPOSITION:PAnsiChar = 'Utils/RestoreWindowPos';

  {
    wParam : 0
    lParam : Pointer to a null terminated string containing filename
    Affect : Loads a bitmap (or other graphic type, see Notes
    Returns: HBITMAP on success, NULL(0) on failure
    Notes  : This function also supports JPEG, GIF (and maybe PNG too)
             For speed, if the file extention is .bmp or .rle it will use LoadImage()
             and not load OLE for the extra image support
             -
             Remember to delete the returned handle with DeleteObject (see GDI documentation for WINAPI)
    Version: v0.1.2.1+
  }
  MS_UTILS_LOADBITMAP:PAnsiChar = 'Utils/LoadBitmap';

  {
      wParam : byte length of buffer (not to be confused with byte range)
      lParam : Pointer to buffer
      Affect : Get the filter strings for use in the open file dialog, see notes
      Returns: 0 on success [non zero] on failure
      Notes  : See the WINAPI under OPENFILENAME.lpStrFiler for formatting,
               an 'All bitmaps' item is alway first, and 'All files' is always last
               -
               The returned string is always formatted
               -
               To build this filter, the filter string consists of
               filter followed by a descriptive text
               followed by more filters and their descriptive texts -- end with double NULL(0)
               e.g. *.bmp' #0 'All bitmaps' #0 '*.*' #0 'All Files' #0 #0
  }
  MS_UTILS_GETBITMAPFILTERSTRINGS:PAnsiChar = 'Utils/GetBitmapFilterStrings';

  {
    wParam : pszPath
    lParam : pszNewPath
    Affect : Saves a path to a relative path (from the miranda directory)
             Only saves as a relative path if the file is in the miranda
             directory (or sub directory)
    Notes  : pszPath is the path to convert and pszNewPath is the buffer that
             the new path is copied too. pszNewPath MUST be of the size MAX_PATH.
    Returns: numbers of chars copied.
  }
  MS_UTILS_PATHTORELATIVE :PAnsiChar = 'Utils/PathToRelative';
//Unicode versions (0.6.2+)
  MS_UTILS_PATHTORELATIVEW:PAnsiChar = 'Utils/PathToRelativeW';

  {
    Affect : Saves a path to a absolute path (from the miranda directory)
    wParam : pszPath
    lParam : pszNewPath
    Notes  : pszPath is the path to convert and pszNewPath is the buffer that
             the new path is copied too. pszNewPath MUST be of the size MAX_PATH.
    Returns: numbers of chars copied.
  }
  MS_UTILS_PATHTOABSOLUTE :PAnsiChar = 'Utils/PathToAbsolute';
//Unicode versions (0.6.2+)
  MS_UTILS_PATHTOABSOLUTEW:PAnsiChar = 'Utils/PathToAbsoluteW';

{
  Creates a directory tree (even more than one directories levels are missing) 0.7.0+
  wParam=0 (unused)
  lParam=pszPath - directory to be created
  Always returns 0
  Unicode version is available since 0.7.0
}
  MS_UTILS_CREATEDIRTREE :PAnsiChar = 'Utils/CreateDirTree';
  MS_UTILS_CREATEDIRTREEW:PAnsiChar = 'Utils/CreateDirTreeW';

{
   Generates Random number of any length
  wParam=size - length of the random number to generate
  lParam=(LPARAM)(char*)pszArray - pointer to array to fill with random number
  Always returns 0
}
  MS_UTILS_GETRANDOM:PAnsiChar = 'Utils/GetRandom';

{
  MD5 interface. 0.7.0.12

  Contains functions for md5 handling
}
// Define the state of the MD5 Algorithm.
type
  pmir_md5_byte_t = ^mir_md5_byte_t;
  pmir_md5_word_t = ^mir_md5_word_t;
  mir_md5_byte_t = byte;     // 8-bit byte
  mir_md5_word_t = cardinal; // 32-bit word

  pmir_md5_state_t = ^mir_md5_state_t;
  mir_md5_state_t = record
    count:array [0..1] of mir_md5_word_t;  // message length in bits, lsw first
    abcd :array [0..3] of mir_md5_word_t;  // digest buffer
    buf  :array [0..63] of mir_md5_byte_t; // accumulate block
  end;

// modified by LA
  TMD5_Digest = array[0..15] of mir_md5_byte_t;
  TMD5_INTERFACE = record
    cbSize:int;
    md5_init  : procedure(var pms:mir_md5_state_t); cdecl;
    md5_append : procedure(var pms:mir_md5_state_t; const data; nbytes:int); cdecl;
    md5_finish : procedure(var pms:mir_md5_state_t; out digest:TMD5_Digest); cdecl;
    md5_hash  : procedure(const data; len:int; out digest:TMD5_Digest); cdecl; //16 byte
  end;
  
{  TMD5_INTERFACE = record
    cbSize:int;
    md5_init   : procedure(pms:pmir_md5_state_t);
    // md5_append : procedure(pms:pmir_md5_state_t; const data:pmir_md5_byte_t; nbytes:int);
	md5_append : procedure(pms:pmir_md5_state_t; const data:pbyte; nbytes:int);
    md5_finish : procedure(pms:pmir_md5_state_t; digest:array of mir_md5_byte_t);
    md5_hash   : procedure(const data:pmir_md5_byte_t; len:int; digest:array of mir_md5_byte_t); //16 byte
  end;}

const
  MS_SYSTEM_GET_MD5I:PAnsiChar = 'Miranda/System/GetMD5I';
{
var
  md5i:MD5_INTERFACE;
}

{
  SHA1 interface. 0.7.0.12

  Contains functions for SHA1 handling
}

type
  pmir_sha1_byte_t = ^mir_sha1_byte_t;
  pmir_sha1_long_t = ^mir_sha1_long_t;
  mir_sha1_byte_t = byte;
  mir_sha1_long_t = longword;

const
  MIR_SHA1_HASH_SIZE = 20;

type
  pmir_sha1_ctx = ^mir_sha1_ctx;
  mir_sha1_ctx = record
    H:array [0..4] of mir_sha1_long_t;
    W:array [0..79] of mir_sha1_long_t;
    lenW:int;
    sizeHi,sizeLo:mir_sha1_long_t;
  end;

  SHA1_INTERFACE = record
    cbSize:int;
    sha1_init   : procedure(ctx:pmir_sha1_ctx);
    sha1_append : procedure(ctx:pmir_sha1_ctx; dataIn:pmir_sha1_byte_t; len:int);
    sha1_finish : procedure(ctx:pmir_sha1_ctx; hashout:array of mir_sha1_byte_t);
    sha1_hash   : procedure(dataIn:pmir_sha1_byte_t; len:int;
                  hashout:array of mir_sha1_byte_t); //20 bytes
  end;

const
  MS_SYSTEM_GET_SHA1I:PAnsiChar = 'Miranda/System/GetSHA1I';

{
var
  sha1i:SHA1_INTERFACE;
}

{$ENDIF}
