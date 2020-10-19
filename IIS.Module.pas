unit IIS.Module;

interface

uses System.Classes, System.SysUtils, Winapi.Windows, Winapi.Isapi2, Web.WebBroker, Web.HTTPApp;

type
  TIISModuleWebRequest = class;

  TRequestNotificationStatus = (RQ_NOTIFICATION_CONTINUE, RQ_NOTIFICATION_PENDING, RQ_NOTIFICATION_FINISH_REQUEST);
  TServerDateVariable = (sdvDate, sdvExpires, sdvLastModified);
  TServerIntegerVariable = (sivContentLength);
  TServerStringVariable = (ssvMethod, ssvProtocol, ssvURL, ssvQueryString, ssvPathInfo, ssvPathTranslated, ssvHTTPCacheControl, ssvHTTPDate, ssvHTTPAccept, ssvHTTPFrom, ssvHTTPHost, ssvHTTPIfModifiedSince, ssvHTTPReferer,
    svHTTPUserAgent, ssvHTTPContentEncoding, ssvContentType, ssvContentLength, ssvHTTPContentVersion, ssvHTTPDerivedFrom, ssvHTTPExpires, ssvHTTPTitle, ssvRemoteAddress, ssvRemoteHost, ssvScriptName, ssvServerPort,
    svContent, ssvHTTPConnection, ssvHTTPCookie, ssvHTTPAuthorization);

  TIISModuleApplication = class(TWebApplication)
  public
    function ExecuteRequest(IISModule: Pointer): Boolean;
  end;

  TIISModule = class
  private
    FIISModule: Pointer;
    FDateVariables: array[TServerDateVariable] of TDateTime;
    FIntegerVariables: array[TServerIntegerVariable] of Integer;
    FStringVariables: array[TServerStringVariable] of String;

    function GetDateVariable(Index: TServerDateVariable): TDateTime;
    function GetHeader(Name: String): String;
    function GetIntegerVariable(Index: TServerIntegerVariable): Integer;
    function GetStringVariable(Index: TServerStringVariable): String;

    procedure SetDateVariable(Index: TServerDateVariable; const Value: TDateTime);
    procedure SetHeader(Name: String; const Value: String);
    procedure SetStringVariable(Index: TServerStringVariable; const Value: String);
    procedure SetIntegerVariable(Index: TServerIntegerVariable; const Value: Integer);
  public
    constructor Create(IISModule: Pointer);

    function WriteClient(var Buffer; const Size: DWORD): DWORD;

    procedure SetStatusCode(StatusCode: Integer; Reason: String);

    property Header[Name: String]: String read GetHeader write SetHeader;
    property DateVariable[Index: TServerDateVariable]: TDateTime read GetDateVariable write SetDateVariable;
    property IntegerVariable[Index: TServerIntegerVariable]: Integer read GetIntegerVariable write SetIntegerVariable;
    property StringVariable[Index: TServerStringVariable]: String read GetStringVariable write SetStringVariable;
  end;

  TIISModuleWebResponse = class(TWebResponse)
  private
    FIISModule: TIISModule;
    FStatusCode: Integer;
    FSent: Boolean;
    FLocalContentStream: TStream;
  protected
    function GetContent: String; override;
    function GetDateVariable(Index: Integer): TDateTime; override;
    function GetIntegerVariable(Index: Integer): Integer; override;
    function GetLogMessage: String; override;
    function GetStatusCode: Integer; override;
    function GetStringVariable(Index: Integer): String; override;

    procedure SetContent(const Value: String); override;
    procedure SetDateVariable(Index: Integer; const Value: TDateTime); override;
    procedure SetIntegerVariable(Index: Integer; Value: Integer); override;
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
  protected
    function GetDateVariable(Index: Integer): TDateTime; override;
    function GetIntegerVariable(Index: Integer): Integer; override;
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

implementation

var
  WebApplication: TIISModuleApplication;

function GetServerStringVariable(IISModule: Pointer; Variable: TServerStringVariable): Pointer; stdcall; external 'IIS.Module.dll';
function RegisterModuleImplementation(pModuleInfo: Pointer; Callback: Pointer): HRESULT; stdcall; external 'IIS.Module.dll';
function WriteClient(Module: Pointer; var Buffer; Size: DWORD): DWORD; stdcall; external 'IIS.Module.dll';

procedure SetStatusCode(Module: Pointer; StatusCode: USHORT; Reason: PUTF8Char); stdcall; external 'IIS.Module.dll';

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
var
  IndexType: TServerDateVariable absolute Index;

begin
  Result := FIISModule.DateVariable[IndexType];
end;

function TIISModuleWebResponse.GetIntegerVariable(Index: Integer): Integer;
var
  IndexType: TServerIntegerVariable absolute Index;

begin
  Result := FIISModule.IntegerVariable[IndexType];
end;

function TIISModuleWebResponse.GetLogMessage: String;
begin

end;

function TIISModuleWebResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TIISModuleWebResponse.GetStringVariable(Index: Integer): String;
var
  IndexType: TServerStringVariable absolute Index;

begin
  Result := FIISModule.StringVariable[IndexType];
end;

procedure TIISModuleWebResponse.SendRedirect(const URI: String);
begin
  inherited;

end;

procedure TIISModuleWebResponse.SendResponse;
begin
  FIISModule.SetStatusCode(StatusCode, StatusString(StatusCode));

  FIISModule.Header['Location'] := Location;
  FIISModule.Header['Allow'] := Allow;

  for var A := 0 to Pred(Cookies.Count) do
    FIISModule.Header['Set-Cookie'] := Cookies[A].HeaderValue;

  FIISModule.Header['Derived-From'] := DerivedFrom;

  if Expires > 0 then
    FIISModule.Header['Expires'] := Format(FormatDateTime(sDateFormat + ' "GMT"', Expires), [DayOfWeekStr(Expires), MonthStr(Expires)]);

  if LastModified > 0 then
    FIISModule.Header['Last-Modified'] := Format(FormatDateTime(sDateFormat + ' "GMT"', LastModified), [DayOfWeekStr(LastModified), MonthStr(LastModified)]);

  FIISModule.Header['Title'] := Title;
  FIISModule.Header['WWW-Authenticate'] := FormatAuthenticate;

  for var A := 0 to Pred(CustomHeaders.Count) do
    FIISModule.Header[CustomHeaders.Names[A]] := CustomHeaders.ValueFromIndex[A];

  FIISModule.Header['Content-Version'] := ContentVersion;
  FIISModule.Header['Content-Encoding'] := ContentEncoding;
  FIISModule.Header['Content-Type'] := ContentType;

  if Assigned(ContentStream) then
  begin
    FIISModule.Header['Content-Length'] := ContentStream.Size.ToString;

    SendStream(ContentStream);
  end;

  FSent := True;
end;

procedure TIISModuleWebResponse.SendStream(AStream: TStream);
var
  Buffer: array[0..65534] of Byte;

  ReadSize: Integer;

begin
  repeat
    ReadSize := AStream.Read(Buffer, Length(Buffer));

    if (ReadSize > 0) and (FIISModule.WriteClient(Buffer, ReadSize) <> ReadSize) then
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
  inherited;

end;

procedure TIISModuleWebResponse.SetIntegerVariable(Index, Value: Integer);
var
  IndexType: TServerIntegerVariable absolute Index;

begin
  FIISModule.IntegerVariable[IndexType] := Value;
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
var
  IndexType: TServerStringVariable absolute Index;

begin
  FIISModule.StringVariable[IndexType] := Value;
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
var
  IndexType: TServerDateVariable absolute Index;

begin
  Result := FIISModule.DateVariable[IndexType];
end;

function TIISModuleWebRequest.GetFieldByName(const Name: String): String;
begin

end;

function TIISModuleWebRequest.GetIntegerVariable(Index: Integer): Integer;
var
  IndexType: TServerIntegerVariable absolute Index;

begin
  Result := FIISModule.IntegerVariable[IndexType];
end;

function TIISModuleWebRequest.GetRawContent: TBytes;
begin

end;

function TIISModuleWebRequest.GetStringVariable(Index: Integer): String;
var
  IndexType: TServerStringVariable absolute Index;

begin
  Result := FIISModule.StringVariable[IndexType];
end;

function TIISModuleWebRequest.ReadClient(var Buffer; Count: Integer): Integer;
begin

end;

function TIISModuleWebRequest.ReadString(Count: Integer): String;
begin

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
    Result := HandleRequest(Request, Response);
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

function TIISModule.GetDateVariable(Index: TServerDateVariable): TDateTime;
begin
  Result := FDateVariables[Index];
end;

function TIISModule.GetHeader(Name: String): String;
begin

end;

function TIISModule.GetIntegerVariable(Index: TServerIntegerVariable): Integer;
begin
  Result := FIntegerVariables[Index];
end;

function TIISModule.GetStringVariable(Index: TServerStringVariable): String;
begin
  if FStringVariables[Index].IsEmpty then
  begin
    var ReturnValue := GetServerStringVariable(FIISModule, Index);

    if Index in [ssvMethod] then
      FStringVariables[Index] := String(PAnsiChar(ReturnValue))
    else
      FStringVariables[Index] := String(PChar(ReturnValue));
  end;

  Result := FStringVariables[Index];
end;

procedure TIISModule.SetDateVariable(Index: TServerDateVariable; const Value: TDateTime);
begin
  FDateVariables[Index] := Value;
end;

procedure TIISModule.SetStringVariable(Index: TServerStringVariable; const Value: String);
begin
  FStringVariables[Index] := Value;
end;

function TIISModule.WriteClient(var Buffer; const Size: DWORD): DWORD;
begin
  Result := IIS.Module.WriteClient(FIISModule, Buffer, Size);
end;

procedure TIISModule.SetHeader(Name: String; const Value: String);
begin

end;

procedure TIISModule.SetIntegerVariable(Index: TServerIntegerVariable; const Value: Integer);
begin
  FIntegerVariables[Index] := Value;
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

