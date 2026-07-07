﻿unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  System.JSON, RESTRequest4D, System.NetEncoding,
  IdHTTP, IdSSLOpenSSL;

type
  TForm1 = class(TForm)
    Label1: TLabel;
    dtpStartDate: TDateTimePicker;
    Label2: TLabel;
    dtpEndDate: TDateTimePicker;
    btnQuery: TButton;
    MemoLog: TMemo;
    Panel1: TPanel;
    procedure btnQueryClick(Sender: TObject);
  private
    FPOSPALAUTHList: TStringList;
    procedure LogMessage(const Msg: string; IsError: Boolean = False);
    procedure SavePOSPALAUTHToConfig(const Value: string);
    function LoginToYinBao: Boolean;
    function FetchBusinessSummary(const StartDate, EndDate: string): Boolean;
    function ParseData(const ResponseContent: string; var TotalAmount, TotalTicketCount, ParkCardAmount: string): Boolean;
    function UploadData(const TotalAmount, TotalTicketCount, ParkCardAmount, SaleDate: string): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

constructor TForm1.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  dtpStartDate.Date := Now ;
  dtpEndDate.Date := Now;
  
  MemoLog.Font.Name := '微软雅黑';
  MemoLog.Font.Size := 12;
  MemoLog.Font.Style := [];

  FPOSPALAUTHList := TStringList.Create;
end;

procedure TForm1.LogMessage(const Msg: string; IsError: Boolean = False);
var
  LogLine: string;
begin
  LogLine := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' - ' + Msg;
  if IsError then
    MemoLog.Lines.Add('ERROR: ' + LogLine)
  else
    MemoLog.Lines.Add('INFO: ' + LogLine);
  MemoLog.SelStart := Length(MemoLog.Text);
  MemoLog.Perform(EM_SCROLLCARET, 0, 0);
end;



procedure TForm1.SavePOSPALAUTHToConfig(const Value: string);
var
  ConfigFile: TStringList;
  ConfigPath: string;
  I: Integer;
begin
  try
    ConfigPath := 'F:\test\抓包银豹数据\config.ini';
    LogMessage('保存 .POSPALAUTH30220 到配置文件: ' + ConfigPath);
    
    ConfigFile := TStringList.Create;
    try
      if FileExists(ConfigPath) then
      begin
        ConfigFile.LoadFromFile(ConfigPath);
        
        for I := 0 to ConfigFile.Count - 1 do
        begin
          if Pos('.POSPALAUTH30220=', ConfigFile[I]) = 1 then
          begin
            ConfigFile[I] := '.POSPALAUTH30220=' + Value;
            LogMessage('更新已存在的配置项');
            Break;
          end;
        end;
        
        if I >= ConfigFile.Count then
        begin
          ConfigFile.Add('');
          ConfigFile.Add('.POSPALAUTH30220=' + Value);
          LogMessage('添加新的配置项');
        end;
      end
      else
      begin
        ConfigFile.Add('[Settings]');
        ConfigFile.Add('.POSPALAUTH30220=' + Value);
        LogMessage('创建新的配置文件');
      end;
      
      ConfigFile.SaveToFile(ConfigPath);
      LogMessage('.POSPALAUTH30220 已保存到配置文件');
      
      if FileExists(ConfigPath) then
        LogMessage('验证: 配置文件保存成功')
      else
        LogMessage('验证: 配置文件保存失败', True);
    finally
      ConfigFile.Free;
    end;
  except
    on E: Exception do
    begin
      LogMessage('保存配置文件失败: ' + E.Message, True);
    end;
  end;
end;



function TForm1.LoginToYinBao: Boolean;
var
  Response: IResponse;
  HomeResponse: IResponse;
  JSONValue: TJSONValue;
  I: Integer;
  HeaderValue: string;
  PosStart: Integer;
begin
  Result := False;
  FPOSPALAUTHList.Clear;

  try
    LogMessage('开始登录银豹平台...');

    Response := TRequest.New
      .BaseURL('https://beta58.pospal.cn')
      .Resource('account/SignIn')
      .AddParam('noLog', '')
      .Accept('application/json, text/javascript, */*; q=0.01')
      .ContentType('application/x-www-form-urlencoded; charset=UTF-8')
      .AddHeader('Accept-Language', 'zh-CN,zh;q=0.9')
      .AddHeader('Cache-Control', 'no-cache')
      .AddHeader('Connection', 'keep-alive')
      .AddHeader('Origin', 'https://beta58.pospal.cn')
      .AddHeader('Pragma', 'no-cache')
      .AddHeader('Referer', 'https://beta58.pospal.cn/account/signin')
      .AddHeader('Sec-Fetch-Dest', 'empty')
      .AddHeader('Sec-Fetch-Mode', 'cors')
      .AddHeader('Sec-Fetch-Site', 'same-origin')
      .AddHeader('User-Agent', 'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Mobile Safari/537.36')
      .AddHeader('X-Requested-With', 'XMLHttpRequest')
      .AddHeader('sec-ch-ua', '"Google Chrome";v="149", "Chromium";v="149", "Not)A;Brand";v="24"')
      .AddHeader('sec-ch-ua-mobile', '?1')
      .AddHeader('sec-ch-ua-platform', '"Android"')
      .AddHeader('Cookie',
        'loginVersionStrForPospal=9942888; ' +
        'browserUuidForPospal=c131db9c-1ba2-459a-8a78-861b4af3c012; ' +
        '_c_WBKFRo=nr4tlrDNSJCxDZ9jlhBoPLzTyy12DOuj2gvNOR6w; ' +
        'lastLoginAccount=taiqishipu001; ' +
        'daysLimitForPospal=; ' +
        'ceMenuMode=0; ' +
        'Hm_lvt_7d46a3151782b7a795ffeba367b5387d=1782206542; ' +
        'POSPAL_REPORT_SDK=v1.0.124; ' +
        'Hm_lvt_8a95882b0d389ebcc438a9230527ddf5=1781682993,1782270786; ' +
        'HMACCOUNT=8E3A3524F67C5A17; ' +
        'storeIndustryForPospal=111; ' +
        'rightPannelCDPAdvert=; ' +
        'sessionGuid=04d58dff-0bb3-4dc3-9200-6cb67bd60758; ' +
        'Hm_lpvt_8a95882b0d389ebcc438a9230527ddf5=1782466015'
      )
      .AddBody(
        'userName=taiqishipu001%3A1002' +
        '&password=grv0532' +
        '&returnUrl=' +
        '&screenSize=1880*384' +
        '&employeeSignin=true'
      )
      .Timeout(30000)
      .Post;

    LogMessage('登录响应:');


    for I := 0 to Response.Headers.Count - 1 do
    begin
      HeaderValue := Response.Headers.ValueFromIndex[I];


      if Pos('SET-COOKIE', UpperCase(Response.Headers.Names[I])) > 0 then
      begin

        if Pos('.POSPALAUTH30220', UpperCase(Response.Headers.Names[I])) > 0 then
        begin
          var AuthValue := Trim(HeaderValue);
          PosStart := Pos(';', AuthValue);
          if PosStart > 0 then
            AuthValue := Trim(Copy(AuthValue, 1, PosStart - 1));
          if AuthValue <> '' then
          begin
            FPOSPALAUTHList.Add(AuthValue);
            LogMessage('获取到POSPALAUTH=' + AuthValue);
          end
        end
      end;
    end;

    JSONValue := TJSONObject.ParseJSONValue(Response.Content);

    if Assigned(JSONValue) then
    try
      if (JSONValue is TJSONObject) and
         (TJSONObject(JSONValue).GetValue('successed') <> nil) and
         (TJSONObject(JSONValue).GetValue('successed').Value = 'true') then
      begin

        LogMessage('登录成功');

        if TJSONObject(JSONValue).GetValue('msg') <> nil then

        Result := True;
      end;
    finally
      JSONValue.Free;
    end;

    if (Result) and (FPOSPALAUTHList.Count = 0) then
    begin
      LogMessage('登录响应未发现POSPALAUTH，尝试访问Home...');

      HomeResponse := TRequest.New
        .BaseURL('https://beta58.pospal.cn')
        .Resource('Home')
        .AddParam('fromSource', 'login')
        .Get;

      LogMessage('========== Home响应头 ==========');
      LogMessage('Header Count=' + IntToStr(HomeResponse.Headers.Count));

      for I := 0 to HomeResponse.Headers.Count - 1 do
      begin
        HeaderValue := HomeResponse.Headers.ValueFromIndex[I];

        if Pos('SET-COOKIE', UpperCase(HomeResponse.Headers.Names[I])) > 0 then
        begin
          if Pos('.POSPALAUTH30220', UpperCase(HomeResponse.Headers.Names[I])) > 0 then
          begin
            var AuthValue := Trim(HeaderValue);
            PosStart := Pos(';', AuthValue);
            if PosStart > 0 then
              AuthValue := Trim(Copy(AuthValue, 1, PosStart - 1));

            if AuthValue <> '' then
            begin
              FPOSPALAUTHList.Add(AuthValue);
              LogMessage('Home页面获取到POSPALAUTH=' + AuthValue);
            end;
          end;
        end;
      end;
    end;

    if FPOSPALAUTHList.Count > 0 then
    begin

      SavePOSPALAUTHToConfig(FPOSPALAUTHList[FPOSPALAUTHList.Count - 1]);
    end
    else
    begin
      LogMessage('未获取到POSPALAUTH', True);
    end;

  except
    on E: Exception do
    begin
      LogMessage('登录异常: ' + E.Message, True);
      Result := False;
    end;
  end;
end;

function TForm1.FetchBusinessSummary(const StartDate, EndDate: string): Boolean;
var
  IdHTTP: TIdHTTP;
  ResponseContent: string;
  BodyStream: TStringStream;
  CookieStr, BodyText: string;
  BeginDT, EndDT: string;
  I: Integer;
begin
  Result := False;
  try
    LogMessage('开始获取门店支付汇总数据，日期范围: ' + StartDate + ' 至 ' + EndDate);

    CookieStr := '';

    for I := 0 to FPOSPALAUTHList.Count - 1 do
    begin
      if CookieStr <> '' then
        CookieStr := CookieStr + '; ';
      CookieStr := CookieStr + '.POSPALAUTH30220=' + FPOSPALAUTHList[I];
    end;

    BeginDT := StringReplace(StartDate, '-', '.', [rfReplaceAll]) + '+00%3A00%3A00';
    EndDT := StringReplace(EndDate, '-', '.', [rfReplaceAll]) + '+23%3A59%3A59';

    BodyText := 'beginDateTime=' + BeginDT + '&endDateTime=' + EndDT + '&userIds%5B%5D=6080897';

    LogMessage('========== 完整请求信息 ==========');

    LogMessage('完整Cookie:');
    LogMessage(CookieStr);
    LogMessage('请求体:');
    LogMessage(BodyText);
    LogMessage('========== 请求信息结束 ==========');

    IdHTTP := TIdHTTP.Create(nil);
    BodyStream := TStringStream.Create(BodyText, TEncoding.UTF8);
    try
      IdHTTP.IOHandler := TIdSSLIOHandlerSocketOpenSSL.Create(IdHTTP);
      IdHTTP.Request.ContentType := 'application/x-www-form-urlencoded; charset=UTF-8';
      IdHTTP.Request.CustomHeaders.Values['Pragma'] := 'no-cache';
      IdHTTP.Request.CustomHeaders.Values['X-Requested-With'] := 'XMLHttpRequest';
      IdHTTP.Request.CustomHeaders.Values['User-Agent'] := 'Apifox/1.0.0 (https://apifox.com)';
      IdHTTP.Request.CustomHeaders.Values['Connection'] := 'keep-alive';
      IdHTTP.Request.CustomHeaders.Values['Cookie'] := CookieStr;
      IdHTTP.Request.CustomHeaders.Values['Accept'] := '*/*';
      IdHTTP.ReadTimeout := 30000;

      ResponseContent := IdHTTP.Post('https://beta58.pospal.cn/ReportV2/LoadStorePaymentSummary', BodyStream);
      LogMessage('门店支付汇总响应:');
      LogMessage(ResponseContent);


      var TotalAmount, TotalTicketCount, ParkCardAmount: string;
      if ParseData(ResponseContent, TotalAmount, TotalTicketCount, ParkCardAmount) then
      begin
        if UploadData(TotalAmount, TotalTicketCount, ParkCardAmount, StartDate) then
        begin
          LogMessage('数据上传成功');
        end
        else
        begin
          LogMessage('数据上传失败', True);
        end;
      end;

      Result := True;
    finally
      BodyStream.Free;
      IdHTTP.Free;
    end;
  except
    on E: Exception do
    begin
      LogMessage('获取门店支付汇总异常: ' + E.Message, True);
    end;
  end;
end;

function TForm1.ParseData(const ResponseContent: string; var TotalAmount, TotalTicketCount, ParkCardAmount: string): Boolean;
var
  JSONValue, JsonObj, ListArray, ItemObj, ParkCardObj: TJSONValue;
begin
  Result := False;
  TotalAmount := '';
  TotalTicketCount := '';
  ParkCardAmount := '';
  try
    LogMessage('开始解析数据...');

    JSONValue := TJSONObject.ParseJSONValue(ResponseContent);
    if not Assigned(JSONValue) then
    begin
      LogMessage('JSON解析失败', True);
      Exit;
    end;

    try
      if JSONValue is TJSONObject then
      begin
        JsonObj := TJSONObject(JSONValue).GetValue('json');
        if Assigned(JsonObj) and (JsonObj is TJSONObject) then
        begin
          ListArray := TJSONObject(JsonObj).GetValue('list');
          if Assigned(ListArray) and (ListArray is TJSONArray) then
          begin
            ItemObj := TJSONArray(ListArray).Items[0];
            if Assigned(ItemObj) and (ItemObj is TJSONObject) then
            begin
              TotalAmount := TJSONObject(ItemObj).GetValue('totalAmount').Value;
              TotalTicketCount := TJSONObject(ItemObj).GetValue('totalTicketCount').Value;
              
              ParkCardObj := TJSONObject(ItemObj).GetValue('园区卡');
              if Assigned(ParkCardObj) and (ParkCardObj is TJSONObject) then
              begin
                ParkCardAmount := TJSONObject(ParkCardObj).GetValue('amount').Value;
              end
              else
              begin
                ParkCardAmount := '0.00';
              end;

              LogMessage('解析结果:');
              LogMessage('  totalAmount: ' + TotalAmount);
              LogMessage('  totalTicketCount: ' + TotalTicketCount);
              LogMessage('  园区卡.amount: ' + ParkCardAmount);

              Result := True;
            end;
          end;
        end;
      end;

      if not Result then
        LogMessage('未找到有效数据', True);
    finally
      JSONValue.Free;
    end;
  except
    on E: Exception do
    begin
      LogMessage('解析数据异常: ' + E.Message, True);
    end;
  end;
end;

function TForm1.UploadData(const TotalAmount, TotalTicketCount, ParkCardAmount, SaleDate: string): Boolean;
var
  LResponse: IResponse;
  JsonBody: string;
begin
  Result := False;
  try
    LogMessage('开始上传数据...');
    
    JsonBody := Format(
      '[{"companyID":%d,"saleMoney":%s,"tradeCount":%d,"saleDate":"%s","shopID":%d,"onlineSaleTotal":%s,"shopName":"%s"}]',
      [819060, TotalAmount, StrToInt(TotalTicketCount), SaleDate, 870378479, ParkCardAmount, '于二饼']
    );
    
    LogMessage('上传数据: ' + JsonBody);

    LResponse := TRequest.New
      .BaseURL('https://hiu.granvida.cn')
      .Resource('api/outer/uploadDaySale')
      .UserAgent('Apifox/1.0.0 (https://apifox.com)')
      .AddHeader('AppKey', 'PB_cssj15pf55eY')
      .AddBody(JsonBody, 'application/json')
      .Accept('application/json')
      .Post;

    if LResponse.StatusCode = 200 then
    begin
      LogMessage('上传响应: ' + LResponse.Content);
      LogMessage('[于二饼] 总计上传成功');
      Result := True;
    end
    else
    begin
      LogMessage('上传失败，状态码: ' + IntToStr(LResponse.StatusCode), True);
    end;
  except
    on E: Exception do
    begin
      LogMessage('数据上传异常: ' + E.Message, True);
    end;
  end;
end;

procedure TForm1.btnQueryClick(Sender: TObject);
var
  StartDate, EndDate: string;
begin
  btnQuery.Enabled := False;
  try
    StartDate := FormatDateTime('yyyy-mm-dd', dtpStartDate.Date);
    EndDate := FormatDateTime('yyyy-mm-dd', dtpEndDate.Date);
    
    if LoginToYinBao then
    begin
      LogMessage('登录成功，开始获取业务汇总数据...');
      FetchBusinessSummary(StartDate, EndDate);
    end;
  finally
    btnQuery.Enabled := True;
  end;
end;

end.