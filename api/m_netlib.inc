{$IFNDEF M_NETLIB}
{$DEFINE M_NETLIB}

{>>/

    NetLib :

    Instead of you writing all the code for working with sockets and supporting
    app level protocols such as SOCKS5, it's all done for you.

    NetLib takes care of all that and you can even register a special abstract
    nexus, e.g. ICQ direct, the user can configure all this from the options dialog
    and you don't have to bother with any of it.

    NetLib wraps up any Winsock calls but you can still get the socket handle
    from your netlib handle and do stuff.

    It gives all modules an abstract way of dealing with transport -- mainly sockets
    and proxies, Now the but..

    It's new (mmmm) thus unsupported by any older version of Miranda, and if you
    want to be lazy and not write any "wrapper" mini netlib then you'll have
    the kudos of "only works with nightly build version of Miranda" :)

/<<}

const
  // for TNETLIBUSER.flags
  NUF_INCOMING      = $01; // bind incoming ports
  NUF_OUTGOING      = $02; // makes outgoing plain connections
  NUF_HTTPGATEWAY   = $04; //can use HTTP gateway for plain sockets.
                           // ???HttpGateway* are valid, enables the HTTP
                           // proxy option, displayed in options
  NUF_NOOPTIONS     = $08; // don't show this as an entry for custom settings to
                           // be defined for, TNETLIB.szDescriptiveName is ignored
  NUF_HTTPCONNS     = $10; // some connections are made for HTTP communication,
                           // enables the HTTP proxy option, displayed in options
  NUF_NOHTTPSOPTION = $20; // Disables the HTTPS proxy option in options, Use
                           // this if all communication is HTTP

  // for TNETLIBUSERSETTINGS.proxyType

  { SOCKS4 -- No DNS or multi addressing mode (proxy side) -- optional username can
  be given, no password }
  PROXYTYPE_SOCKS4 = 1;
  { SOCKS5 -- DNS names can be given as addresses to connect to, optional
  plain text username/password scheme (which may cause failure due to denied access)
  IP address maybe returned for DNS addresses -- thus server side DNS }
  PROXYTYPE_SOCKS5 = 2;
  PROXYTYPE_HTTP   = 3;
  PROXYTYPE_HTTPS  = 4;

  NETLIBBIND_SIZEOF_V1 = 16; // sizeof(NETLIBBIND) prior to 0.3.4+ (2004/08/05)
  NETLIBBIND_SIZEOF_V2 = 20; // sizeof(NETLIBBIND) prior to 0.6+ (2006/07/03)

  // for TNETLIBOPENCONNECTION.flags

  { this connection will be useed for HTTP communications,
  if configured for an HTTP(S) proxy the connection is opened as if there
  was no proxy }
  NLOCF_HTTP = $0001;
  { this connection should send the sticky headers associated with NetLib
   user apart of any HTTP request}
  NLOCF_STICKYHEADERS = $0002;
  { this connection understands the newer structure, newer cbSize isnt enough}
  NLOCF_V2 = $0004;

  NETLIBOPENCONNECTION_V1_SIZE = 16;
  // old sizeof() is 14 bytes, but there is padding of 2 bytes

  // for TNETLIBHTTPPROXYINFO.flags

  NLHPIF_USEGETSEQUENCE      = $0001; // append sequence numbers to GET requests
  NLHPIF_USEPOSTSEQUENCE     = $0002; // append sequence numbers to POST requests
  NLHPIF_GETPOSTSAMESEQUENCE = $0004; // GET and POST use the same sequence
  NLHPIF_HTTP11              = $0008;	// HTTP 1.1 proxy

  // for TNETLIBHTTPREQUEST.flags, .requestType

  { used by MS_NETLIB_RECVHTTPHEADERS returned structure }

  REQUEST_RESPONSE = 0;
  REQUEST_GET      = 1;
  REQUEST_POST     = 2;
  REQUEST_CONNECT  = 3;
  REQUEST_HEAD     = 4; // new in 0.5.1

  NLHRF_GENERATEHOST    = $00000001; // auto generate a 'host' header from .szUrl
  NLHRF_REMOVEHOST      = $00000002; // remove any host and/or protocol portion
                                     // of szUrl before sending it
  NLHRF_SMARTREMOVEHOST = $00000004; // removes host and/or protocol from szUrl
                                     // unless the connection was opened through
                                     // an HTTP or HTTPS proxy.
  NLHRF_SMARTAUTHHEADER = $00000008; // if the connection was opened through an
                                     // HTTP or HTTPS proxy then send a
                                     // Proxy-Authorization header if required.
  NLHRF_HTTP11          = $00000010; //use HTTP 1.1
  NLHRF_NODUMP          = $00010000; // never dump this to the log
  NLHRF_NODUMPHEADERS   = $00020000; // don't dump http headers (only useful for
                                     // POSTs and MS_NETLIB_HTTPTRANSACTION
  NLHRF_DUMPPROXY       = $00040000; // this transaction is a proxy communication.
                                     // For dump filtering only.
  NLHRF_DUMPASTEXT      = $00080000; // dump posted and reply data as text.
                                     // Headers are always dumped as text.

  // for TNETLIBBUFFER.flags

  MSG_NOHTTPGATEWAYWRAP = $010000; // don't wrap outgoing packet using
                                   // TNETLIBUSER.pfnHttpGatewayWrapSend
  MSG_NODUMP            = $020000; // don't dump this packet to the log
  MSG_DUMPPROXY         = $040000; // this is proxy communication, for dump
                                   // filtering only
  MSG_DUMPASTEXT        = $080000; // don't dump as hex, it's text
  MSG_RAW               = $100000; // send as raw, bybpass HTTP proxy stuff


// all record types structures are declared in their own block because the C
// header file used forward declaration (to get typed parameters for certain
// function pointers). This sort of define-type-pointer-before-type can only be
// done in the same type block in D2 (don't know about later versions)

  FD_SETSIZE = 65;

type
    { forward typed pointers to records }
  PNETLIBOPENCONNECTION = ^TNETLIBOPENCONNECTION;
  PNETLIBHTTPREQUEST    = ^TNETLIBHTTPREQUEST;

  { This function pointer is to the CRT realloc() used by Miranda -- it allows reallocation of memory passed
  to us (not that we could EVER share the same CRT) but to allow DLLs in general to reallocate memory }
  TNetlibRealloc = function(Mem: Pointer; size_t: int): Pointer; cdecl;
  TNetlibHTTPGatewayInitProc  = function(hConn: THandle; nloc: PNETLIBOPENCONNECTION; nlhr: PNETLIBHTTPREQUEST): int; cdecl;
  TNetlibHTTPGatewayBeginProc = function(hConn: THandle; nloc: PNETLIBOPENCONNECTION): int; cdecl;
  TNetlibHTTPGatewayWrapSendProc = function(hConn: THandle; buf: PByte; len: int; flags: int; pfnNetLibSend: TMIRANDASERVICE): int; cdecl;
  TNetlibHTTPGatewayUnwrapRecvProc = function(nlhr: PNETLIBHTTPREQUEST; buf: PByte; len: int; outBufLen: pInt; NetlibRealloc: TNetlibRealloc): PByte; cdecl;

  PNETLIBUSER = ^TNETLIBUSER;
  TNETLIBUSER = record
    cbSize: int;
    szSettingsModule: PChar;  // used for DB settings and log, 'NL' stuff
    szDescriptiveName: PChar; // shows a descriptive name for which different proxy settings can be defined
    flags: DWORD;             // see NUF_* constants above
    szHttpGatewayHello: PChar;
    szHttpGatewayUserAgent: PChar; // can be NULL(0) to send no User-Agent: also used by HTTPS proxies
    pfnHttpGatewayInit: TNetlibHTTPGatewayInitProc;
    pfnHttpGatewayBegin: TNetlibHTTPGatewayBeginProc; // can be NULL(0) if no begin is required
    pfnHttpGatewayWrapSend: TNetlibHTTPGatewayWrapSendProc; // can be NULL(0) if no wrapping is required
    pfnHttpGatewayUnwrapRecv: TNetlibHTTPGatewayUnwrapRecvProc; // can be NULL(0) "      "
    minIncomingPorts: int; // only if NUF_INCOMING, will be used for validation of user input
  end;

  PNETLIBUSERSETTINGS = ^TNETLIBUSERSETTINGS;
  TNETLIBUSERSETTINGS = record
    cbSize              :int;   // filled before calling
    useProxy            :int;   // 1 or 0
    proxyType           :int;   // PROXYTYPE_* constant, see above
    szProxyServer       :PChar; // can be NULL(0)
    wProxyPort          :int;   // in host byte order
    useProxyAuth        :int;   // 1 or 0, always 0 for SOCKS4 (doesn't have auth)
    szProxyAuthUser     :PChar; // can be NULL(0), always used by SOCKS4
    szProxyAuthPassword :PChar; // can be NULL(0)
    useProxyAuthNtlm    :int;   // 1 or 0, only used by HTTP, HTTPS
    dnsThroughProxy     :int;   // 1 or 0
    specifyIncomingPorts:int;   // 1 or 0
    szIncomingPorts     :PChar; // can be NULL(0), form '1024-1050,1060-1070,2000'
	  specifyOutgoingPorts:int;   // 0.3.3a+
	  szOutgoingPorts     :PChar; // 0.3.3a+
    enableUPnP          :int;   // 0.6.1+ only for NUF_INCOMING
  end;

  TNetlibNewConnectionProc    = procedure(hNewConnection:THandle; dwRemoveIP:DWORD); cdecl;
  TNetlibNewConnectionProc_V2 = procedure(hNewConnection:THandle; dwRemoveIP:DWORD; pExtra:pointer); cdecl;

  PNETLIBBINDOLD = ^TNETLIBBINDOLD;
  TNETLIBBINDOLD = record
    cbSize: int;
    pfnNewConnection:TNetlibNewConnectionProc; // function to call when there's
                                               // a new connection, dwRemoteIP is
                                               // in host byte order -- the handle
                                               // is to the new connection
    dwInternalIP: DWORD;                       // set on return, host byte order
    wPort: WORD;                               // set on return, host byte order
  end;

  PNETLIBBIND = ^TNETLIBBIND;
  TNETLIBBIND = record
    cbSize:int;
    // new code should use V2
  	pfnNewConnection:TNETLIBNEWCONNECTIONPROC;
    // or pfnNewConnectionV2:NETLIBNEWCONNECTIONPROC_V2;
    //function to call when there's a new connection. Params are: the
    //new connection, IP of remote machine (host byte order)
    dwInternalIP:DWORD;    //set on return, host byte order
    wPort       :DWORD;    //set on return, host byte order
    pExtra      :^pointer; //argument is sent to callback, added during 0.3.4+
    dwExternalIP:DWORD;    //set on return, host byte order
    wExPort     :word;     //set on return, host byte order
  end;

  twaitcallback = function(timeout:dword):integer; cdecl;
  { Pointered type is above }
  TNETLIBOPENCONNECTION = record
    cbSize : int;
    szHost : PChar; // can be an IP in string form
    wPort  : Word;
    flags  : DWORD; // see NLOCF_* flags
    timeout: Cardinal;
    // optional, called in the context of the thread that issued the attempt,
    // if it returns 0 the connection attempt is stopped, the remaining
    // timeout value can also be adjusted
	  waitcallback:twaitcallback;
  end;

  PNETLIBHTTPPROXYINFO = ^TNETLIBHTTPPROXYINFO;
  TNETLIBHTTPPROXYINFO = record
    cbSize           : int;
    flags            : DWORD; // see NLHPIF_* above
    szHttpPostUrl    : PChar;
    szHttpGetUrl     : PChar;
    firstGetSequence : int;
    firstPostSequence: int;
  end;

  PNETLIBBASE64 = ^TNETLIBBASE64;
  TNETLIBBASE64 = record
    pszEncoded: PChar;
    cchEncoded: int;
    pbDecoded : PByte;
    cbDecoded : int;
  end;

  PNETLIBHTTPHEADER = ^TNETLIBHTTPHEADER;
  TNETLIBHTTPHEADER = record
    szName : PChar;
    szValue: PChar;
  end;

  { PNETLIBHTTPREQUEST = ^TNETLIBHTTPREQUEST, defined above because this is
  forward referenced from there }
  TNETLIBHTTPREQUEST = record
    cbSize       :int;
    requestType  :int;               // REQUEST_* constant
    flags        :DWORD;
    szUrl        :PChar;
    { doesn't contain Content-Length, it'll be added automatically }
    // headers      :PNETLIBHTTPHEADER; // pointer to an array of em?
    // next line is corrected by LA
    headers      : array of TNETLIBHTTPHEADER;
    headersCount :int;               // yes they do
    pData        :PChar;             // data to be sent on POST request
    dataLength   :int;               // must be 0 for REQUEST_GET/REQUEST_CONNECT
    resultCode   :int;
    szResultDescr:PChar;
    nlc          :THANDLE;
  end;

  PNETLIBBUFFER = ^TNETLIBBUFFER;
  TNETLIBBUFFER = record
    buf  : PChar;
    len  : int;
    flags: int; // see MSG_* constants above
  end;

  PNETLIBSELECT = ^TNETLIBSELECT;
  TNETLIBSELECT = record
    cbSize      : int;
    dwTimeout   : DWORD; // in milliseconds, INFINITE is acceptable
    hReadConns  : array [0..FD_SETSIZE] of THandle;
    hWriteConns : array [0..FD_SETSIZE] of THandle;
    hExceptConns: array [0..FD_SETSIZE] of THandle;
  end;

  PNETLIBSELECTEX = ^TNETLIBSELECTEX;
  TNETLIBSELECTEX = record
    cbSize      : int;
    dwTimeout   : DWORD; // in milliseconds, INFINITE is acceptable
    hReadConns  : array [0..FD_SETSIZE] of THandle;
    hWriteConns : array [0..FD_SETSIZE] of THandle;
    hExceptConns: array [0..FD_SETSIZE] of THandle;
    // Added in v0.3.3+
    hReadStatus  : array [0..FD_SETSIZE] of BOOL; // out, [in, expected to be FALSE]
    hWriteStatus : array [0..FD_SETSIZE] of BOOL; // out, [in, expected to be FALSE]
    hExceptStatus: array [0..FD_SETSIZE] of BOOL; // out, [in, expected to be FALSE]
  end;

  PNETLIBPACKETRECVER = ^TNETLIBPACKETRECVER;
  TNETLIBPACKETRECVER = record
    cbSize        : int;
    dwTimeout     : DWORD; // infinite is allowed -- initialise before use
    bytesUsed     : int;   // this many bytes are removed from the start of the
                           // buffer, set to 0 on return -- initialise before use
    bytesAvailable: int;   // equal the returnd value by service, unless the
                           // return value is 0 (connection closed)
    bufferSize    : int;   // same as the parameter given to
                           // MS_NETLIB_CREATEPACKETRECVER: wParam
    buffer        : PByte; // contains the read data
  end;

const
  {
    wParam : 0
    lParam : Pointer to an initalised TNETLIBUSER structure
    Affects: Initialises the netlib for a set of connections, see notes
    Returns: Returns a handle for future netlib calls, NULL on failure.
    Notes  : Netlib is loaded AFTER all plugins, thus a call to this service
             in Load() will fail, hook ME_SYSTEM_MODULESLOADED and call it
             from there.
             -
             Netlib will save settings under .szSettings module, all settings
             (being?) begin with 'NL'.
             -
             Defacto settings are the same as <All connections> combobox entry option
             as seen in Miranda->Options->Network
    Version: v0.1.2.2+
    Errors : ERROR_INVALID_PARAMETER, ERROR_OUTOFMEMORY, ERROR_DUP_NAME
  }
  MS_NETLIB_REGISTERUSER = 'Netlib/RegisterUser';

{
  Assign a Netlib user handle a set of dynamic HTTP headers to be used with all

  HTTP connections that enable the HTTP-use-sticky headers flag. 
  The headers persist until cleared with lParam=NULL.

  All memory should be allocated by the caller using malloc() from MS_SYSTEM_GET_MMI
  Once it has passed to Netlib, Netlib is the owner of it, the caller should not refer to the memory
  In any way after this point.

  wParam=(WPARAM)hNetLibUser
  lParam=(LPARAM)(char*)szHeaders

  NOTE: The szHeaders parameter should be a NULL terminated string following the HTTP header syntax.
  This string will be injected verbatim, thus the user should be aware of setting strings that are not
  headers. This service is NOT THREAD SAFE, only a single thread is expected to set the headers and a single
  thread reading the pointer internally, stopping race conditions and mutual exclusion don't happen.

  Version 0.3.2a+ (2003/10/27)
}
  MS_NETLIB_SETSTICKYHEADERS = 'Netlib/SetStickyHeaders';

  {
    wParam : HANDLE
    lParam : Pointer to a initalised TNETLIBUSERSETTINGS structure
    Affects: Gets the user configured settings for a Netlib user, see notes
    Returns: [non zero] on SUCCESS, NULL(0) on failure
    Notes  : .cbSize must be filled with sizeof() before calling --
             the returned null terminated strings (in the structure) are valid
             as long as HANDLE remains open or proxy options are changed
             again, do not rely on them being around forever.
    Version: v0.1.2.2+
    Errors : ERROR_INVALID_PARAMETER
  }
  MS_NETLIB_GETUSERSETTINGS = 'Netlib/GetUserSettings';

  {
    wParam : HANDLE
    lParam : Pointer to a initalised NETLIBUSERSETTINGS structure
    Affect : Changes the configurable settings for a Netlib user -- see notes
    Returns: [non zero] on success, NULL(0) on failure
    Notes  : This service is only really useful for people that specify NUF_NOOPTIONS
             when registering and want to create their own options.
             Settings will be stored even if the option to enable it, is it not enabled,
             e.g. useProxyAuth is 0, szProxyAuthPassword will still be saved
    Errors : ERROR_INVALID_PARAMETER
  }
  MS_NETLIB_SETUSERSETTINGS = 'Netlib/SetUserSettings';

  {
    wParam : HANDLE / SOCKET
    lParam : 0
    Affects: Closes a handle, see notes
    Returns: Returns [non zero] on success, NULL(0) on failure
    Notes  : All netlib handles should be closed once they're finished with,
             If a SOCKET type is passed instead of netlib handle type, it is closed
    Errors : ERROR_INVALID_PARAMETER
  }
  MS_NETLIB_CLOSEHANDLE = 'Netlib/CloseHandle';

  {
    wParam : HANDLE
    lParam : Pointer to a initialised TNETLIBBIND
    Affects: Open a port and wait for connections on it -- see notes
    Returns: Returns a handle on success, NULL(0) on failure
    Notes  : this function does the equivalent of socket(), bind(), getsockname(),
             listen(), accept() -- internally this function creates a new thread
             which waits around in accept() for new connections.
             When one is received, TNETLIBBIND.pfnNewConnection is called,
             from the context of the NEW thread and then it
             returns to waiting for connections.
             -
             Close the returned handle to end the thread and close the port.
             -
    Errors : ERROR_INVALID_PARAMETER, any returned by socket(), bind(), listen()
             getsockname()
  }
  MS_NETLIB_BINDPORT = 'Netlib/BindPort';

  {
    wParam : HANDLE
    lParam : Pointer to an initalised TNETLIBOPENCONNECTION structure
    Affects: Opens a connection -- see notes
    Returns: Returns a Handle to a new connection on success, NULL(0) on failure
    Notes  : internally this service is the equivalent of socket(), gethostbyname(),
             connect()
             -
             If NLOCF_HTTP is set and HANDLE is configured for HTTP(S) proxy
             then this function will connect() to that proxy server ONLY,
             without performing any initialisation conversation.
             -
             If HANDLE is configured for an HTTP proxy and does not support
             HTTP gateways and you try to open a connection without NLOCF_HTTP
             then this service will first attempt to open an HTTPS connection,
             if that fails, it will try a direct connection, if *that* fails
             then it will return failure with the error
             from connect() during the connection attempt
    Errors : ERROR_INVALID_PARAMETER, any returned by socket(), gethostbyname(),
             connect(), MS_NETLIB_SEND, MS_NETLIB_RECV, select()
             -
             ERROR_TIMEOUT (during proxy communication)
             ERROR_BAD_FORMAT (very invalid proxy reply)
             ERROR_ACCESS_DENIED (by proxy)
             ERROR_CONNECTION_UNAVAIL (socks proxy can't connect to identd)
             ERROR_INVALID_ACCESS (proxy refused identd auth)
             ERROR_INVALID_DATA (proxy returned invalid code)
             ERROR_INVALID_ID_AUTHORITY (proxy requires use of auth method that's not supported)
             ERROR_GEN_FAILURE (socks5/https general failure)
             ERROR_CALL_NOT_IMPLEMENTED (socks5 command not supported)
             ERROR_INVALID_ADDRESS (socks5 address type not supported)
             -
             HTTP: anything from TNETLIBUSER.pfnHttpGatewayInit, TNETLIBUSER.pfnHttpGatewayBegin,
                   MS_NETLIB_SENDHTTPREQUEST or MS_NETLIB_RECVHTTPHEADERS
  }
  MS_NETLIB_OPENCONNECTION = 'Netlib/OpenConnection';

  {
    wParam : HANDLE
    lParam : Pointer to an initialised NETLIBHTTPPROXYINFO structure
    Affects: Sets the required information for an HTTP proxy connection -- see notes
    Returns: [non zero] on success, NULL(0) on failure
    Notes  : This service is designed to be called from
             within TNETLIBUSER.pfnHttpGatewayInit (see notes in C header under
             MS_NETLIB_REGISTERUSER)
    Errors : ERROR_INVALID_PARAMETER
  }
  MS_NETLIB_SETHTTPPROXYINFO = 'Netlib/SetHttpProxyInfo';

  {
    wParam : HANDLE
    lParam : 0
    Affects: Get's the SOCKET associated with a handle -- see notes
    Returns: the SOCKET on success, INVALID_SOCKET on failure
    Notes  : The Netlib handle passed to this service should only be passed
             if they were returned with MS_NETLIB_OPENCONNECTION or MS_NETLIB_BINDPORT
             -
             Be careful how you use this socket because you might be connected via an
             HTTP proxy, in which case calling send/recv() will break things
             -
    Errors : ERROR_INVALID_PARAMETER
  }
  MS_NETLIB_GETSOCKET = 'Netlib/GetSocket';

  {
    wParam : 0
    lParam : Pointer to a null terminated string
    Affects: URL-encodes a string for x-www-form-urlencoded (and other uses) -- see notes
    Returns: A pointer to a null terminated string, NULL(0) on failure
    Notes  : The returned string must be freed after it's no longer needed,
             to do this Miranda's process heap must be used (under the WINAPI), e.g.
             HeapFree(GetProcessHeap(), 0, the_returned_string)
    Errors : ERROR_INVALID_PARAMETER, ERROR_OUTOFMEMORY
  }
  MS_NETLIB_URLENCODE = 'Netlib/UrlEncode';

  {
    wParam : 0
    lParam : Pointer to a TNETLIBBASE64 initialised structure
    Affects: Decodes a Base64 null terminated string, see notes
    Returns: [non zero] on success, NULL(0) on failure
    Notes  : TNETLIBBASE64.pszEncoded and cchEncoded must contain a pointer to
             a buffer to use as input, and it's length, the length
             should not include space taken for null termination --
             -
             Output is placed in ..pbDecoded and ..cbDecoded for buffer and
             length of buffer -- the maxiumum output for a given input can
             be worked out with Netlib_GetBase64DecodedBufferSize() function
             see below.
             -
             For more information on Base64 see rfc-1421.
    Errors : ERROR_INVALID_PARAMETER, ERROR_INVALID_DATA, ERROR_BUFFER_OVERFLOW
  }
  MS_NETLIB_BASE64DECODE = 'Netlib/Base64Decode';

  {
    wParam : 0
    lParam : Pointer to an initialised TNETLIBBASE64 structure
    Affect : Base64 encode a string, see notes
    Returns: [non zero] on success, NULL(0) on failure
    Notes  : TNETLIBBASE64.pbDecode and TNETLIBBASE64.cbDecoded contain
             the input buffer and it's length --
             TNETLIBBASE64.pszEncoded and TNETLIBBASE64.cchEncoded contain the
             buffer in which to put the output and it's length.
             -
             The maximum output size for a given input can be worked
             out with the function Netlib_GetBase64EncodedBufferSize() below
             .pszEncoded is null terminated, on return TNETLIBBASE64.cchEncoded
             is set to the actual length excluding 0.
    Errors : ERROR_INVALID_PARAMETER, ERROR_BUFFER_OVERFLOW
  }
  MS_NETLIB_BASE64ENCODE = 'Netlib/Base64Encode';

  {
    wParam : HANDLE
    lParam : Pointer to a initialised TNETLIBHTTPREQUEST structure
    Affect : Send an HTTP request over a connection, see notes
    Returns: The number of bytes on success, SOCKET_ERROR on failure
    Notes  : HANDLE must of been returned by MS_NETLIB_OPENCONNECTION,,
             If you use NLHRF_SMARTAUTHHEADER and NTLM auth is in use then
             full NTLM auth transcation occurs, comprising sending the
             domain, getting the challenge, sending the response.
             NETLIBHTTPREQUEST.resultCode and NETLIBHTTPREQUEST.szResultDescr are
             ignored by this service.
    Errors : ERROR_INVALID_PARAMETER, MS_NETLIB_SEND (return codes)
  }
  MS_NETLIB_SENDHTTPREQUEST = 'Netlib/SendHttpRequest';

  {
    wParam : HANDLE
    lParam : 0
    Affect : Receive HTTP headers, see notes
    Returns: A pointer to a TNETLIBHTTPREQUEST structure on success, NULL(0) on failure
    Notes  : The returned pointer must be freed after it's done with
             use MS_NETLIB_FREEHTTPREQUESTSTRUCT.
             -
             HANDLE must be returned by MS_NETLIB_OPENCONNECTION
             -
             Return^.pData=NIL and Return^.dataLength=0 always
             -
             The returned data should be retrieved using MS_NETLIB_RECV once
             the headers have been parsed.
             If headers haven't finished within 60 seconds the function returns
             NULL(0) and ERROR_TIMEOUT
    Errors : ERROR_INVALID_PARAMETER, any MS_NETLIB_RECV or select()
             ERROR_HANDLE_EOF (connection closed bfore headers complete)
             ERROR_TIMEOUT (headers still not complete after 60 seconds)
             ERROR_BAD_FORMAT (invalid character or line ending in headers, or first line is blank)
             ERROR_BUFFER_OVERFLOW (each header line must be less than 4096 chars long)
             ERROR_INVALID_DATA (first header line is malformed ("http/[01].[0-9] [0-9]+ .*", or no colon in subsequent line)

  }
  MS_NETLIB_RECVHTTPHEADERS = 'Netlib/RecvHttpHeaders';

  {
    wParam : 0
    lParam : Pointer returned by MS_NETLIB_RECVHTTPHEADERS to free
    Affect : Free the memory used by a TNETLIBHTTPREQUEST structure, see notes
    Returns: [non zero] on success, NULL(0) on failure
    Notes  : This service should only be used with memory pointers returned
             by either MS_NETLIB_RECVHTTPHEADERS or MS_NETLIB_HTTPTRANSACTION!.
    Errors : ERROR_INVALID_PARAMETER

  }
  MS_NETLIB_FREEHTTPREQUESTSTRUCT = 'Netlib/FreeHttpRequestStruct';

  {
    wParam : HANDLE
    lParam : Pointer to a TNETLIBHTTPREQUEST structure
    Affect : Carry out an entire HTTP transaction, see notes
    Returns: another pointer to a TNETLIBHTTPREQUEST structure or NULL(0)
             on failure
    Notes  : The returned pointer must be freed at some point
             with MS_NETLIB_FREEHTTPREQUESTSTRUCT,
             -
             TNETLIBHTTPREQUEST.szUrl should have a full HTTP URL, if it
             does not start with http://, that will be assumed, but do not
             take this assumption to stay assumed (heh..) in the future
             -
             this service equivalent of open(), sendhttp(), getheaders()
             netlib_recv(), netlib_closehandle()
             -
             TNETLIBHTTPREQUEST.headers will be added to with the following
             headers if they're not already present :
             "Host" (even if it is requested in .flags)
             "User-Agent" (in form : 'Miranda/d.d.d.d <(status of release)>')
             "Content-Length" (for POSTs only, set to TNETLIBHTTPREQUEST.dataLength)

             If you don't want to send any of these headers --
             set TNETLIBHTTPREQUEST.headers to NULL(0)
             -
             In the returned pointer, pData[dataLen] is always 0 for 'safety'
             also : headers, headersCount, pData, dataLength, resultCode and
                    szResultDescr are all valid
             -
             Also take care not to assume that a returned pointer means that
             at the HTTP level it all worked out -- refer to the resultCode for
             2xx before doing anything else
             -
    Errors : ERROR_INVALID_PARAMETER, ERROR_OUTOFMEMORY
             Errors returned by the aforementioned internally used functions
  }
  MS_NETLIB_HTTPTRANSACTION = 'Netlib/HttpTransaction';

  {
    wParam : HANDLE
    lParam : Pointer to an initialised TNETLIBBUFFER structure
    Affect : Send data over an open connection see notes
    Returns: The number of bytes sent on success, SOCKET_ERROR on failure
    Notes  : see Netlib_Send() helper function
    Errors : ERROR_INVALID_PARAMETER,
             anything from socket(), connect()
             send(), TNETLIBUSER.pfnHttpGatewayWrapSend(),
             (HTTP proxy): ERROR_GEN_FAILURE (http result code wasn't 2xx)
             MS_NETLIB_SENDHTTPREQUEST, MS_NETLIB_RECVHTTPHEADERS
  }
  MS_NETLIB_SEND = 'Netlib/Send';

  {
    wParam : HANDLE
    lParam : Pointer to an initialised TNETLIBBUFFER structure
    Affect : Receive data over a connection, see notes
    Returns: The number of bytes read on success, SOCKET_ERROR on failure
    Notes  :
             This service uses some of the same flags as MS_NETLIB_SEND :
             MSG_PEEK,
             MSG_NODUMP,
             MSG_DUMPPROXY,
             MSG_NOHTTPGATEWAYWRAP,
             MSG_DUMPASTEXT,
             MSG_RAW
             -
             On using MSG_NOHTTPGATEWAYWRAP: Because packets through an HTTP proxy are
             batched and cached and stuff, using this flag is not a guarantee that it
             will be obeyed, and if it is it may even be propogated to future calls
             even if you don't specify it then. Because of this, the flag should be
             considered an all-or-nothing thing: either use it for the entire duration
             of a connection, or not at all.
    Errors : ERROR_INVALID_PARAMETER, anything from recv()
             (HTTP proxy):
             ERROR_GEN_FAILURE (http result code wasn't 2xx)
             ERROR_INVALID_DATA (no Content-Length header in reply)
             ERROR_NOT_ENOUGH_MEMORY (Content-Length very large)
             ERROR_HANDLE_EOF (connection closed before Content-Length bytes recved)
                               anything from select(),
             MS_NETLIB_RECVHTTPHEADERS, nlu.pfnHttpGatewayUnwrapRecv, socket(),
             connect(), MS_NETLIB_SENDHTTPREQUEST

  }
  MS_NETLIB_RECV = 'Netlib/Recv';

  {
    wParam : 0
    lParam : Pointer to an initialised TNETLIBSELECT structure
    Affect : Determine the status of one or more connections, see notes
    Returns: The numbe of ready connections, SOCKET_ERROR on failure
    Notes  : All handles passed to this service must have been returned
             either by MS_NETLIB_OPENCONNECTION or MS_NETLIB_BINDPORT,
             the last handle in each list must be followed by either NULL
             or INVALID_HANDLE_VALUE.
    Errors : ERROR_INVALID_HANDLE, ERROR_INVALID_DATA, anything from select()
  }
  MS_NETLIB_SELECT = 'Netlib/Select';
  MS_NETLIB_SELECTEX = 'Netlib/SelectEx'; // added in v0.3.3

  {
    wParam : HANDLE
    lParam : maxPacketSize
    Affect : Create a packet receiver, see notes
    Returns: A handle on success, NULL(0) on failure
    Notes  : The packet receiver implements the common situation where
             you have a variable length of packets coming thru over a connection
             and you want them split up in order to handle them.
             -
             The major limiation is, that the buffer is created in memory,
             so you can't have arbitrarily large packets
    Errors : ERROR_INVALID_PARAMETER, ERROR_OUTOFMEMORY
  }
  MS_NETLIB_CREATEPACKETRECVER = 'Netlib/CreatePacketRecver';

  {
    wParam : Handle returned by MS_NETLIB_CREATEPACKETRECVER
    lParam : Pointer to an initialised TNETLIBPACKETRECVER
    Returns: The total number of bytes available in the buffer, NULL(0)
             if the connection was closed or SOCKET_ERROR.
             -
             If TNETLIBPACKETRECVER.bytesUsed is set to zero and the
             buffer is already full up to the maxPacketSize, it is assumed
             that a too large packet has been received, All data in
             the buffer is discarded and receiving has started anew.
             -
             This will probably cause alignment problem so if you think
             that tis iss likely to happen, then you should deal with it
             yourself.
             -
             Closing the packet receiver will not close the associated
             connection but will discard any bytes still in the buffer,
             so if you intend to carry on reading from that connection,
             make sure you have processed the buffer first.
             -
             This service is equivalent of memmove() to remove
             the first bytesUsed from the buffer, select(), if dwTimeOut
             is not INFINITE, then MS_NETLIB_RECV
    Errors : ERROR_INVALID_PARAMETER, ERROR_TIMEOUT, anything from select(),
             MS_NETLIB_RECV
  }
  MS_NETLIB_GETMOREPACKETS = 'Netlib/GetMorePackets';

  {
    wParam : HANDLE
    lParam : Pointer to null terminated string to uh, log.
    Affect : Add a message to the log (if it's running) see notes
    Returns: non zeror on success, NULL(0) on failure
    Notes  : Don't include \r\n or #13#10 it's not needed,
             -
             Doesn't support formatting like the given C code for
             Netlib_Logf, just use FmtStr() and then call this service
             if you want that.
    Errors : ERROR_INVALID_PARAMETER
  }
  MS_NETLIB_LOG = 'Netlib/Log';

  {
    Sets a gateway polling timeout interval
    wParam=(WPARAM)(HANDLE)hConn
    lParam=(LPARAM)timeout
    Returns previous timeout value
    Errors: -1
  }
  MS_NETLIB_SETPOLLINGTIMEOUT = 'Netlib/SetPollingTimeout';

/////////////////////////////////////////////////////////////////////////////////////////
// Security providers (0.6+)

// Inits a required security provider. Right now only NTLM is supported
// Returns HANDLE = NULL on error or non-null value on success
  MS_NETLIB_INITSECURITYPROVIDER = 'Netlib/InitSecurityProvider';

// Destroys a security provider's handle, provided by Netlib_InitSecurityProvider.
// Right now only NTLM is supported
  MS_NETLIB_DESTROYSECURITYPROVIDER = 'Netlib/DestroySecurityProvider';

// Returns the NTLM response string. The result value should be freed using mir_free
  MS_NETLIB_NTLMCREATERESPONSE = 'Netlib/NtlmCreateResponse';

type
  NETLIBNTLMREQUEST = record
    szChallenge:PChar;
    userName   :PChar;
    password   :PChar;
  end;
(*
static __inline char* Netlib_NtlmCreateResponse( HANDLE hProvider, char* szChallenge, char* login, char* psw )
{
	NETLIBNTLMREQUEST temp = { szChallenge, login, psw };
	return (char* )CallService( MS_NETLIB_NTLMCREATERESPONSE, (WPARAM)hProvider, (LPARAM)&temp );
}
*)
{$ENDIF}
