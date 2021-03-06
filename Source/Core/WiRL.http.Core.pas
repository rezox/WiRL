{******************************************************************************}
{                                                                              }
{       WiRL: RESTful Library for Delphi                                       }
{                                                                              }
{       Copyright (c) 2015-2018 WiRL Team                                      }
{                                                                              }
{       https://github.com/delphi-blocks/WiRL                                  }
{                                                                              }
{******************************************************************************}
unit WiRL.http.Core;

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes;

type
  TWiRLHttpMethod = (GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS, TRACE, CONNECT);

  TWiRLHttpMethodHelper = record helper for TWiRLHttpMethod
  public
    class function ConvertFromString(const AMethod: string): TWiRLHttpMethod; static;
  public
    function ToString: string;
    procedure FromString(const AMethod: string);
  end;

  TWiRLHttpStatus = class
  public const
    // 1xx Informational
    CONTINUE_REQUEST                = 100;
    SWITCHING_PROTOCOLS             = 101;
    PROCESSING                      = 102;
    CHECKPOINT                      = 103;

    // 2xx Success
    OK                              = 200;
    CREATED                         = 201;
    ACCEPTED                        = 202;
    NON_AUTHORITATIVE_INFORMATION   = 203;
    NO_CONTENT                      = 204;
    RESET_CONTENT                   = 205;
    PARTIAL_CONTENT                 = 206;
    MULTI_STATUS                    = 207;
    ALREADY_REPORTED                = 208;
    IM_USED                         = 226;

    // 3xx Redirection
    MULTIPLE_CHOICES                = 300;
    MOVED_PERMANENTLY               = 301;
    MOVED_TEMPORARILY               = 302;  // Deprecated
    FOUND                           = 302;
    SEE_OTHER                       = 303;
    NOT_MODIFIED                    = 304;
    USE_PROXY                       = 305;
    TEMPORARY_REDIRECT              = 307;
    PERMANENT_REDIRECT              = 308;

    // --- 4xx Client Error ---
    BAD_REQUEST                     = 400;
    UNAUTHORIZED                    = 401;
    PAYMENT_REQUIRED                = 402;
    FORBIDDEN                       = 403;
    NOT_FOUND                       = 404;
    METHOD_NOT_ALLOWED              = 405;
    NOT_ACCEPTABLE                  = 406;
    PROXY_AUTHENTICATION_REQUIRED   = 407;
    REQUEST_TIMEOUT                 = 408;
    CONFLICT                        = 409;
    GONE                            = 410;
    LENGTH_REQUIRED                 = 411;
    PRECONDITION_FAILED             = 412;
    PAYLOAD_TOO_LARGE               = 413;
    REQUEST_ENTITY_TOO_LARGE        = 413;
    URI_TOO_LONG                    = 414;
    REQUEST_URI_TOO_LONG            = 414;
    UNSUPPORTED_MEDIA_TYPE          = 415;
    REQUESTED_RANGE_NOT_SATISFIABLE = 416;
    EXPECTATION_FAILED              = 417;
    I_AM_A_TEAPOT                   = 418;
    INSUFFICIENT_SPACE_ON_RESOURCE  = 419;
    METHOD_FAILURE                  = 420;
    DESTINATION_LOCKED              = 421;
    UNPROCESSABLE_ENTITY            = 422;
    LOCKED                          = 423;
    FAILED_DEPENDENCY               = 424;
    UPGRADE_REQUIRED                = 426;
    PRECONDITION_REQUIRED           = 428;
    TOO_MANY_REQUESTS               = 429;
    REQUEST_HEADER_FIELDS_TOO_LARGE = 431;
    UNAVAILABLE_FOR_LEGAL_REASONS   = 451;

    // --- 5xx Server Error ---
    INTERNAL_SERVER_ERROR           = 500;
    NOT_IMPLEMENTED                 = 501;
    BAD_GATEWAY                     = 502;
    SERVICE_UNAVAILABLE             = 503;
    GATEWAY_TIMEOUT                 = 504;
    HTTP_VERSION_NOT_SUPPORTED      = 505;
    VARIANT_ALSO_NEGOTIATES         = 506;
    INSUFFICIENT_STORAGE            = 507;
    LOOP_DETECTED                   = 508;
    BANDWIDTH_LIMIT_EXCEEDED        = 509;
    NOT_EXTENDED                    = 510;
    NETWORK_AUTHENTICATION_REQUIRED = 511;
  private
    FCode: Integer;
    FLocation: string;
    FReason: string;
  public
    constructor Create; overload;
    constructor Create(ACode: Integer); overload;
    constructor Create(ACode: Integer; const AReason: string); overload;
    constructor Create(ACode: Integer; const AReason, ALocation: string); overload;

    property Code: Integer read FCode write FCode;
    property Reason: string read FReason write FReason;
    property Location: string read FLocation write FLocation;
  end;

  TWiRLHeaderList = class(TStringList)
  private
    function GetName(AIndex: Integer): string;
    function GetValue(const AName: string): string;
    procedure SetValue(const AName, AValue: string);
    function GetValueFromLine(AIndex: Integer): string;
  public
    function IndexOfName(const AName: string): Integer; reintroduce;
    property Names[Index: Integer]: string read GetName;
    property Values[const Name: string]: string read GetValue write SetValue; default;
    property ValueFromIndex[Index: Integer]: string read GetValueFromLine;
  end;

  TWiRLParam = class(TStringList)
  private
    function GetValue(const Name: string): string;
    procedure SetValue(const Name, Value: string);
  public
    property Values[const Name: string]: string read GetValue write SetValue; default;
  end;

var
  GetDefaultCharSetEncoding: TEncoding = nil;

function EncodingFromCharSet(const ACharset: string): TEncoding;

implementation

uses
  System.TypInfo;

function DefaultCharSetEncoding: TEncoding;
begin
  Result := nil;
  if Assigned(GetDefaultCharSetEncoding) then
    Result := GetDefaultCharSetEncoding;
  if Result = nil then
    Result := TEncoding.UTF8;
end;

function EncodingFromCharSet(const ACharset: string): TEncoding;
begin
  if CompareText('utf-8', ACharset) = 0 then
    Result := TEncoding.UTF8
  else if CompareText('ISO-8859-1', ACharset) = 0 then
    Result := TEncoding.ANSI
  else if CompareText('ANSI', ACharset) = 0 then
    Result := TEncoding.ANSI
  else if CompareText('ASCII', ACharset) = 0 then
    Result := TEncoding.ASCII
  else
    Result := DefaultCharSetEncoding;
end;

{ TWiRLHeaderList }

const
  HeaderNameValueSeparator = ': ';

function TWiRLHeaderList.GetName(AIndex: Integer): string;
var
  LLine: string;
  LTrimmedSeparator: string;
  LSepIndex: Integer;
begin
  if (AIndex >= 0) and (AIndex < Count) then
  begin
    LLine := Get(AIndex);
    LTrimmedSeparator := Trim(HeaderNameValueSeparator); // Sometimes the space is not present
    LSepIndex := LLine.IndexOf(LTrimmedSeparator);
    Result := LLine.Substring(0, LSepIndex).Trim;
  end
  else
  begin
    Result := '';
  end;
end;

function TWiRLHeaderList.GetValueFromLine(AIndex: Integer): string;
var
  LLine: string;
  LTrimmedSeparator: string;
  LSepIndex: Integer;
begin
  if (AIndex >= 0) and (AIndex < Count) then
  begin
    LLine := Get(AIndex);
    LTrimmedSeparator := Trim(HeaderNameValueSeparator); // Sometimes the space is not present
    LSepIndex := LLine.IndexOf(LTrimmedSeparator);
    Result := LLine.Substring(LSepIndex + 1).Trim;
  end
  else
  begin
    Result := '';
  end;
end;

function TWiRLHeaderList.GetValue(const AName: string): string;
var
  LIndex: Integer;
begin
  LIndex := IndexOfName(AName);
  Result := GetValueFromLine(LIndex);
end;

function TWiRLHeaderList.IndexOfName(const AName: string): Integer;
var
  LIndex: Integer;
begin
  Result := -1;
  for LIndex := 0 to Count - 1 do
  begin
    if CompareText(GetName(LIndex), AName) = 0 then
    begin
      Exit(LIndex);
    end;
  end;
end;

procedure TWiRLHeaderList.SetValue(const AName, AValue: string);
var
  LIndex: Integer;
begin
  LIndex := IndexOfName(AName);
  if AValue <> '' then
  begin
    if LIndex < 0 then
      LIndex := Add('');
    Put(LIndex, AName + HeaderNameValueSeparator + AValue);
  end
  else if LIndex >= 0 then
    Delete(LIndex);
end;

{ TWiRLParam }

function TWiRLParam.GetValue(const Name: string): string;
begin
  Result := inherited Values[Name];
end;

procedure TWiRLParam.SetValue(const Name, Value: string);
begin
  inherited Values[Name] := Value;
end;

{ TWiRLHttpMethodHelper }

procedure TWiRLHttpMethodHelper.FromString(const AMethod: string);
begin
  Self := ConvertFromString(AMethod);
end;

class function TWiRLHttpMethodHelper.ConvertFromString(const AMethod: string): TWiRLHttpMethod;
var
  LRes: Integer;
begin
  LRes := GetEnumValue(TypeInfo(TWiRLHttpMethod), AMethod);
  if LRes >= 0 then
    Result := TWiRLHttpMethod(LRes)
  else
    raise Exception.Create('Error converting string type');
end;

function TWiRLHttpMethodHelper.ToString: string;
begin
  case Self of
    TWiRLHttpMethod.GET:     Result := 'GET';
    TWiRLHttpMethod.HEAD:    Result := 'HEAD';
    TWiRLHttpMethod.POST:    Result := 'POST';
    TWiRLHttpMethod.PUT:     Result := 'PUT';
    TWiRLHttpMethod.PATCH:   Result := 'PATCH';
    TWiRLHttpMethod.DELETE:  Result := 'DELETE';
    TWiRLHttpMethod.OPTIONS: Result := 'OPTIONS';
    TWiRLHttpMethod.TRACE:   Result := 'TRACE';
    TWiRLHttpMethod.CONNECT: Result := 'CONNECT';
  end;
end;

{ TWiRLHttpStatus }

constructor TWiRLHttpStatus.Create(ACode: Integer);
begin
  Create(ACode, '', '');
end;

constructor TWiRLHttpStatus.Create(ACode: Integer; const AReason: string);
begin
  Create(ACode, AReason, '');
end;

constructor TWiRLHttpStatus.Create(ACode: Integer; const AReason, ALocation: string);
begin
  FCode := ACode;
  FReason := AReason;
  FLocation := ALocation;
end;

constructor TWiRLHttpStatus.Create;
begin
  Create(200, '', '');
end;

end.
