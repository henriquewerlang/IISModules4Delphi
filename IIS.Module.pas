unit IIS.Module;

interface

uses System.Classes, System.SysUtils, System.Rtti, System.Generics.Collections, Winapi.Windows, Winapi.Isapi2, Web.WebBroker, Web.HTTPApp;

type
  TIISModuleWebRequest = class;

{$IF CompilerVersion >= 35}
  TIntegerVariable = Int64;
{$ELSE}
  TIntegerVariable = Integer;
{$ENDIF}

  TRequestNotificationStatus = (RQ_NOTIFICATION_CONTINUE, RQ_NOTIFICATION_PENDING, RQ_NOTIFICATION_FINISH_REQUEST);
  TServerVariable = (ssvMethod, ssvProtocol, ssvURL, ssvQueryString, ssvPathInfo, ssvPathTranslated, ssvHTTPCacheControl, ssvHTTPDate, ssvHTTPAccept, ssvHTTPFrom, ssvHTTPHost,
    ssvHTTPIfModifiedSince, ssvHTTPReferer, ssvHTTPUserAgent, ssvHTTPContentEncoding, ssvContentType, ssvContentLength, ssvHTTPContentVersion, ssvHTTPDerivedFrom, ssvHTTPExpires,
    ssvHTTPTitle, ssvRemoteAddress, ssvRemoteHost, ssvScriptName, ssvServerPort, ssvNotDefined, ssvHTTPConnection, ssvHTTPCookie, ssvHTTPAuthorization);

  TIISModuleApplication = class(TWebApplication)
  public
    function ExecuteRequest(IISModule: Pointer): Boolean;
  end;

  TIISModule = class
  private
    FIISModule: Pointer;
    FServerVariables: array [TServerVariable] of String;

    function GetHeader(Name: String): String;
    function GetServerVariable(Index: TServerVariable): String;

    procedure SetHeader(Name: String; const Value: String);
    procedure SetServerVariable(Index: TServerVariable; const Value: String);
  public
    constructor Create(IISModule: Pointer);

    function ReadClient(var Buffer; Count: Integer): Integer;
    function WriteClient(var Buffer; const Size: DWORD): DWORD;

    procedure SetStatusCode(StatusCode: Integer; Reason: String);

    property Header[Name: String]: String read GetHeader write SetHeader;
    property ServerVariable[Index: TServerVariable]: String read GetServerVariable write SetServerVariable;
  end;

  TIISModuleWebResponse = class(TWebResponse)
  private
    FIISModule: TIISModule;
    FStatusCode: Integer;
    FSent: Boolean;
    FLocalContentStream: TStream;
    FStringVariables: array[0..MAX_STRINGS - 1] of UTF8String;
    FIntegerVariables: array[0..MAX_INTEGERS - 1] of TIntegerVariable;
    FDateVariables: array[0..MAX_DATETIMES - 1] of TDateTime;
  protected
    function GetContent: String; override;
    function GetDateVariable(Index: Integer): TDateTime; override;
    function GetIntegerVariable(Index: Integer): TIntegerVariable; override;
    function GetLogMessage: String; override;
    function GetStatusCode: Integer; override;
    function GetStringVariable(Index: Integer): String; override;

    procedure SetContent(const Value: String); override;
    procedure SetDateVariable(Index: Integer; const Value: TDateTime); override;
    procedure SetIntegerVariable(Index: Integer; Value: TIntegerVariable); override;
    procedure SetLogMessage(const Value: String); override;
    procedure SetStatusCode(Value: Integer); override;
    procedure SetStringVariable(Index: Integer; const Value: String); override;
  public
    constructor Create(HTTPRequest: TIISModuleWebRequest);

    function Sent: Boolean; override;

    procedure SendResponse; override;
    procedure SendRedirect(const URI: String); override;
    procedure SendStream(AStream: TStream); override;
  end;

  TIISModuleWebRequest = class(TWebRequest)
  private
    FIISModule: TIISModule;
    FContent: TBytes;

    procedure LoadContent;
  protected
    function GetDateVariable(Index: Integer): TDateTime; override;
    function GetIntegerVariable(Index: Integer): TIntegerVariable; override;
    function GetRawContent: TBytes; override;
    function GetStringVariable(Index: Integer): String; override;
  public
    constructor Create(IISModule: Pointer);

    destructor Destroy; override;

    function GetFieldByName(const Name: String): String; override;
    function ReadClient(var Buffer; Count: Integer): Integer; override;
    function ReadString(Count: Integer): String; override;
    function TranslateURI(const URI: String): String; override;
    function WriteClient(var Buffer; Count: Integer): Integer; override;
    function WriteHeaders(StatusCode: Integer; const ReasonString, Headers: String): Boolean; override;
    function WriteString(const AString: String): Boolean; override;
  end;

function RegisterModule(dwServerVersion: DWORD; pModuleInfo, pGlobalInfo: Pointer): HRESULT; stdcall;

exports
  RegisterModule;

implementation

var
  WebApplication: TIISModuleApplication;

function GetServerVariable(IISModule: Pointer; Variable: TServerVariable): Pointer; stdcall; external 'IIS.Module.dll';
function ReadContent(IISModule: Pointer; var Buffer; const BufferSize: DWORD; var BytesReaded: DWORD): HRESULT; safecall; stdcall; external 'IIS.Module.dll';
function ReadHeader(Module: Pointer; HeaderName: LPCSTR; var ValueSize: USHORT): LPCSTR; stdcall; external 'IIS.Module.dll';
function RegisterModuleImplementation(pModuleInfo: Pointer; Callback: Pointer): HRESULT; stdcall; external 'IIS.Module.dll';
function WriteClient(Module: Pointer; var Buffer; Size: DWORD): DWORD; stdcall; external 'IIS.Module.dll';

procedure SetStatusCode(Module: Pointer; StatusCode: USHORT; Reason: PUTF8Char); stdcall; external 'IIS.Module.dll';
procedure WriteHeader(Module: Pointer; HeaderName, Value: LPCSTR; ValueSize: USHORT); stdcall; external 'IIS.Module.dll';

function Callback(IISModule: Pointer): TRequestNotificationStatus; stdcall;
begin
  if WebApplication.ExecuteRequest(IISModule) then
    Result := RQ_NOTIFICATION_FINISH_REQUEST
  else
    Result := RQ_NOTIFICATION_CONTINUE;
end;

function RegisterModule(dwServerVersion: DWORD; pModuleInfo, pGlobalInfo: Pointer): HRESULT;
begin
  Result := RegisterModuleImplementation(pModuleInfo, @Callback);
end;

{ TIISModuleWebResponse }

constructor TIISModuleWebResponse.Create(HTTPRequest: TIISModuleWebRequest);
begin
  FIISModule := HTTPRequest.FIISModule;

  inherited Create(HTTPRequest);
end;

function TIISModuleWebResponse.GetContent: String;
begin

end;

function TIISModuleWebResponse.GetDateVariable(Index: Integer): TDateTime;
begin
  Result := FDateVariables[Index];
end;

function TIISModuleWebResponse.GetIntegerVariable(Index: Integer): TIntegerVariable;
begin
  Result := FIntegerVariables[Index];
end;

function TIISModuleWebResponse.GetLogMessage: String;
begin

end;

function TIISModuleWebResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TIISModuleWebResponse.GetStringVariable(Index: Integer): String;
begin
  Result := String(FStringVariables[Index]);
end;

procedure TIISModuleWebResponse.SendRedirect(const URI: String);
begin
  inherited;

end;

procedure TIISModuleWebResponse.SendResponse;
begin
  FIISModule.SetStatusCode(StatusCode, StatusString(StatusCode));

  FIISModule.Header['Allow'] := Allow;
  FIISModule.Header['Content-Encoding'] := ContentEncoding;
  FIISModule.Header['Content-Type'] := ContentType;
  FIISModule.Header['Content-Version'] := ContentVersion;
  FIISModule.Header['Derived-From'] := DerivedFrom;
  FIISModule.Header['Location'] := Location;
  FIISModule.Header['Title'] := Title;
  FIISModule.Header['WWW-Authenticate'] := FormatAuthenticate;

  for var A := 0 to Pred(Cookies.Count) do
    FIISModule.Header['Set-Cookie'] := Cookies[A].HeaderValue;

  if Expires > 0 then
    FIISModule.Header['Expires'] := Format(FormatDateTime(sDateFormat + ' "GMT"', Expires), [DayOfWeekStr(Expires), MonthStr(Expires)]);

  if LastModified > 0 then
    FIISModule.Header['Last-Modified'] := Format(FormatDateTime(sDateFormat + ' "GMT"', LastModified), [DayOfWeekStr(LastModified), MonthStr(LastModified)]);

  for var A := 0 to Pred(CustomHeaders.Count) do
    FIISModule.Header[CustomHeaders.Names[A]] := CustomHeaders.ValueFromIndex[A];

  if Assigned(ContentStream) then
  begin
    FIISModule.Header['Content-Length'] := ContentStream.Size.ToString;

    SendStream(ContentStream);
  end;

  FSent := True;
end;

procedure TIISModuleWebResponse.SendStream(AStream: TStream);
var
  Buffer: array[Word] of Byte;

  ReadSize: Integer;

begin
  repeat
    ReadSize := AStream.Read(Buffer, Length(Buffer));

    if (ReadSize > 0) and (FIISModule.WriteClient(Buffer, ReadSize) <> Cardinal(ReadSize)) then
      raise Exception.Create('Problemas no envio dos dados!');
  until ReadSize = 0;
end;

function TIISModuleWebResponse.Sent: Boolean;
begin
  Result := FSent;
end;

procedure TIISModuleWebResponse.SetContent(const Value: String);
begin
  if not Assigned(FLocalContentStream) then
    FLocalContentStream := TMemoryStream.Create;

  FLocalContentStream.Size := 0;

  var Bytes := DefaultCharSetEncoding.GetBytes(Value);

  FLocalContentStream.Write(Bytes, Length(Bytes));

  FLocalContentStream.Seek(0, TSeekOrigin.soBeginning);

  ContentStream := FLocalContentStream;

  FreeContentStream := True;
end;

procedure TIISModuleWebResponse.SetDateVariable(Index: Integer; const Value: TDateTime);
begin
  FDateVariables[Index] := Value;
end;

procedure TIISModuleWebResponse.SetIntegerVariable(Index: Integer; Value: TIntegerVariable);
begin
  FIntegerVariables[Index] := Value;
end;

procedure TIISModuleWebResponse.SetLogMessage(const Value: String);
begin
  inherited;

end;

procedure TIISModuleWebResponse.SetStatusCode(Value: Integer);
begin
  FStatusCode := Value;
end;

procedure TIISModuleWebResponse.SetStringVariable(Index: Integer; const Value: String);
begin
  FStringVariables[Index] := UTF8String(Value);
end;

{ TIISModuleWebRequest }

constructor TIISModuleWebRequest.Create(IISModule: Pointer);
begin
  FIISModule := TIISModule.Create(IISModule);

  inherited Create;
end;

destructor TIISModuleWebRequest.Destroy;
begin
  FIISModule.Free;

  inherited;
end;

function TIISModuleWebRequest.GetDateVariable(Index: Integer): TDateTime;
begin
  if GetStringVariable(Index).IsEmpty then
    Result := 0
  else
    Result := StrToDateTime(GetStringVariable(Index));
end;

function TIISModuleWebRequest.GetFieldByName(const Name: String): String;
begin
  Result := FIISModule.Header[Name];
end;

function TIISModuleWebRequest.GetIntegerVariable(Index: Integer): TIntegerVariable;
begin
  if GetStringVariable(Index).IsEmpty then
    Result := 0
  else
    Result := GetStringVariable(Index).ToInteger;
end;

function TIISModuleWebRequest.GetRawContent: TBytes;
begin
  if not Assigned(FContent) then
    LoadContent;

  Result := FContent;
end;

function TIISModuleWebRequest.GetStringVariable(Index: Integer): String;
var
  ServerIndex: TServerVariable absolute Index;

begin
  Result := FIISModule.ServerVariable[ServerIndex];
end;

procedure TIISModuleWebRequest.LoadContent;
var
  TotalToRead: Int64;

begin
  TotalToRead := 0;

  SetLength(FContent, ContentLength);

  repeat
    var TotalReaded := ReadClient(FContent[TotalToRead], Length(FContent) - TotalToRead);

    TotalToRead := TotalToRead + TotalReaded;
  until TotalToRead = Length(FContent);
end;

function TIISModuleWebRequest.ReadClient(var Buffer; Count: Integer): Integer;
begin
  Result := FIISModule.ReadClient(Buffer, Count);
end;

function TIISModuleWebRequest.ReadString(Count: Integer): String;
var
  Len: Integer;

  LResult: TBytes;

begin
  SetLength(LResult, Count);

  Len := ReadClient(LResult[0], Count);

  if Len > 0 then
    SetLength(LResult, Len)
  else
    SetLength(LResult, 0);

  Result := DefaultCharSetEncoding.GetString(LResult);
end;

function TIISModuleWebRequest.TranslateURI(const URI: String): String;
begin

end;

function TIISModuleWebRequest.WriteClient(var Buffer; Count: Integer): Integer;
begin
  Result := FIISModule.WriteClient(Buffer, Count);
end;

function TIISModuleWebRequest.WriteHeaders(StatusCode: Integer; const ReasonString, Headers: String): Boolean;
begin
  Result := True;
end;

function TIISModuleWebRequest.WriteString(const AString: String): Boolean;
begin
  Result := True;

  WriteClient(Pointer(AString)^, AString.Length * 2);
end;

{ TIISModuleApplication }

function TIISModuleApplication.ExecuteRequest(IISModule: Pointer): Boolean;
begin
  var Request := TIISModuleWebRequest.Create(IISModule);
  var Response := TIISModuleWebResponse.Create(Request);

  try
    Result := HandleRequest(Request, Response) or Response.Sent;
  finally
    Response.Free;

    Request.Free;
  end;
end;

{ TIISModule }

constructor TIISModule.Create(IISModule: Pointer);
begin
  inherited Create;

  FIISModule := IISModule;
end;

function TIISModule.GetHeader(Name: String): String;
var
  AnsiValue: LPCSTR;

  HeadValueSize: USHORT;

begin
  AnsiValue := ReadHeader(FIISModule, PAnsiChar(AnsiString(Name)), HeadValueSize);

  Result := String(Copy(AnsiValue, 1, HeadValueSize));
end;

function TIISModule.GetServerVariable(Index: TServerVariable): String;
begin
  if FServerVariables[Index].IsEmpty then
  begin
    var ReturnValue := IIS.Module.GetServerVariable(FIISModule, Index);

    if Index in [ssvContentLength, ssvContentType, ssvHTTPCookie, ssvMethod] then
      FServerVariables[Index] := String(PAnsiChar(ReturnValue))
    else
      FServerVariables[Index] := String(PChar(ReturnValue));

    if Index = ssvQueryString then
      FServerVariables[Index] := FServerVariables[Index].Substring(1);
  end;

  Result := FServerVariables[Index];
end;

function TIISModule.ReadClient(var Buffer; Count: Integer): Integer;
var
  BytesReaded: DWORD;

begin
  ReadContent(FIISModule, Buffer, Count, BytesReaded);

  Result := BytesReaded;
end;

function TIISModule.WriteClient(var Buffer; const Size: DWORD): DWORD;
begin
  Result := IIS.Module.WriteClient(FIISModule, Buffer, Size);
end;

procedure TIISModule.SetHeader(Name: String; const Value: String);
begin
  if not Value.IsEmpty then
  begin
    var AnsiValue := AnsiString(Value);

    IIS.Module.WriteHeader(FIISModule, PAnsiChar(AnsiString(Name)), PAnsiChar(AnsiValue), Length(AnsiValue));
  end;
end;

procedure TIISModule.SetServerVariable(Index: TServerVariable; const Value: String);
begin
  FServerVariables[Index] := Value;
end;

procedure TIISModule.SetStatusCode(StatusCode: Integer; Reason: String);
var
  ReasonAnsiString: AnsiString;

begin
  ReasonAnsiString := AnsiString(Reason + #0);

  IIS.Module.SetStatusCode(FIISModule, StatusCode, @ReasonAnsiString[1]);
end;

initialization
  WebApplication := TIISModuleApplication.Create(nil);

  Application := WebApplication;

end.

