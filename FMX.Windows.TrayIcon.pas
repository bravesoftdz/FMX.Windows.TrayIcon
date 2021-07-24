unit FMX.Windows.TrayIcon;

{
  Author: AkyrosXD
  GitHub: https://github.com/AkyrosXD
  Platform: Windows
  Framework: Firemonkey / FMX
}

interface

uses
  Winapi.Windows, Winapi.ShellAPI, Winapi.Messages, FMX.Types, FMX.Platform.Win,
  FMX.Forms, FMX.Menus, System.Classes, System.SysUtils, FMX.Dialogs;

type
  TBalloonType = (None = 0, Info = 1, Warning = 2, Error = 3);

type
  TTrayIcon = class(TComponent)
  private
    var
      notifyIconData: _NOTIFYICONDATA;
      bVisible: Boolean;
    procedure OnMenuToggleClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetOnClick(AOnClick: TNotifyEvent);
    procedure SetOnDoubleClick(AOnDoubleClick: TNotifyEvent);
    function GetPopupMenu: TPopupMenu;
    function AddMenuAction(AText: string; AOnClick: TNotifyEvent): TMenuItem;
    function AddMenuToggle(AText: string; AOnActivate, AOnDeactivate: TNotifyEvent; ADefaultValue: Boolean): TMenuItem;
    procedure ShowBalloon(ATitle, AText: string; AType: TBalloonType);
    procedure Show(ATip: string);
    procedure Hide;
  end;

implementation

var
  s_callbackMessage: UINT;
  s_pOnClick: TNotifyEvent;
  s_pOnDoubleClick: TNotifyEvent;
  s_ptrOldWindowProc: Pointer;
  s_menu: TPopupMenu;
  s_contextMenuHandle: HWND;
  s_contextMenuWindow: TForm;

function WndProcCallback(hWindow: HWND; uMsg: UINT; wpParam: WPARAM; lpParam: LPARAM): LRESULT; stdcall;
var
  mousePosition: TPoint;
begin
  if uMsg = s_callbackMessage then
  begin
    case lpParam of
      WM_LBUTTONDOWN:
        if Assigned(s_pOnClick) then
        begin
          s_pOnClick(nil);
        end;

      WM_LBUTTONDBLCLK:
        if Assigned(s_pOnDoubleClick) then
        begin
          s_pOnDoubleClick(nil);
        end;

      WM_RBUTTONDOWN:
        if Assigned(s_menu) and (s_contextMenuHandle <> 0) then
        begin
          SetForegroundWindow(s_contextMenuHandle);
          GetCursorPos(mousePosition);
          s_menu.Popup(mousePosition.X, mousePosition.Y);
        end;
    end;
  end;
  Result := CallWindowProc(s_ptrOldWindowProc, hWindow, uMsg, wpParam, lpParam);
end;

constructor TTrayIcon.Create(AOwner: TComponent);
begin
  if AOwner = nil then
  begin
    raise Exception.Create('AOwner cannot be null');
  end;
  bVisible := False;
  s_contextMenuWindow := TForm.CreateNew(nil);
  s_contextMenuHandle := WindowHandleToPlatform(s_contextMenuWindow.Handle).Wnd;
  inherited Create(s_contextMenuWindow);
  s_callbackMessage := WM_USER + Self.InstanceSize; // it has to be something unique
  s_menu := TPopupMenu.Create(s_contextMenuWindow);
  s_menu.Parent := s_contextMenuWindow;
  with notifyIconData do
  begin
    cbSize := SizeOf;
    Wnd := s_contextMenuHandle;
    uID := Cardinal(s_contextMenuHandle);
    uFlags := NIF_MESSAGE or NIF_ICON or NIF_TIP;
    dwInfoFlags := NIIF_NONE;
    uCallbackMessage := s_callbackMessage;
    hIcon := GetClassLong(s_contextMenuHandle, GCL_HICONSM)
  end;
end;

destructor TTrayIcon.Destroy;
begin
  Shell_NotifyIcon(NIM_DELETE, @notifyIconData);
  inherited;
end;

procedure TTrayIcon.SetOnClick(AOnClick: TNotifyEvent);
begin
  s_pOnClick := AOnClick;
end;

procedure TTrayIcon.SetOnDoubleClick(AOnDoubleClick: TNotifyEvent);
begin
  s_pOnDoubleClick := AOnDoubleClick;
end;

function TTrayIcon.GetPopupMenu: TPopupMenu;
begin
  Result := s_menu;
end;

function TTrayIcon.AddMenuAction(AText: string; AOnClick: TNotifyEvent): TMenuItem;
var
  item: TMenuItem;
begin
  item := nil;
  if Assigned(s_menu) then
  begin
    item := TMenuItem.Create(s_menu);
    item.Parent := s_menu;
    item.Text := AText;
    item.OnClick := AOnClick;
    s_menu.AddObject(item);
  end;
  Result := item;
end;

procedure TTrayIcon.OnMenuToggleClick(Sender: TObject);
var
  item: TMenuItem;
begin
  item := Sender as TMenuItem;
  item.IsChecked := (not item.IsChecked);
  if item.IsChecked then
  begin
    item.OnActivate(Sender);
  end
  else
  begin
    item.OnDeactivate(Sender);
  end;
end;

function TTrayIcon.AddMenuToggle(AText: string; AOnActivate, AOnDeactivate: TNotifyEvent; ADefaultValue: Boolean): TMenuItem;
var
  item: TMenuItem;
begin
  item := nil;
  if Assigned(s_menu) then
  begin
    item := TMenuItem.Create(s_menu);
    item.Parent := s_menu;
    item.Text := AText;
    item.IsChecked := ADefaultValue;
    item.OnActivate := AOnActivate;
    item.OnDeactivate := AOnDeactivate;
    item.OnClick := OnMenuToggleClick;
    s_menu.AddObject(item);
  end;
  Result := item;
end;

procedure TTrayIcon.ShowBalloon(ATitle, AText: string; AType: TBalloonType);
begin
  if bVisible then
  begin
    StrLCopy(notifyIconData.szInfoTitle, PChar(ATitle), High(notifyIconData.szInfoTitle));
    StrLCopy(notifyIconData.szInfo, PChar(AText), High(notifyIconData.szInfo));
    notifyIconData.dwInfoFlags := Cardinal(AType);
    notifyIconData.uFlags := NIF_INFO;
    Shell_NotifyIcon(NIM_MODIFY, @notifyIconData);

    // reset everything after the message
    FillChar(notifyIconData.szInfoTitle, High(notifyIconData.szInfoTitle), 0);
    FillChar(notifyIconData.szInfo, High(notifyIconData.szInfo), 0);
    notifyIconData.dwInfoFlags := NIIF_NONE;
    notifyIconData.uFlags := NIF_MESSAGE or NIF_ICON or NIF_TIP;
    Shell_NotifyIcon(NIM_MODIFY, @notifyIconData);
  end;
end;

procedure TTrayIcon.Show(ATip: string);
begin
  if not bVisible then
  begin
    if not Assigned(s_ptrOldWindowProc) then
    begin
      s_ptrOldWindowProc := Pointer(GetWindowLongPtr(s_contextMenuHandle, GWL_WNDPROC));
      SetWindowLongPtr(s_contextMenuHandle, GWL_WNDPROC, Integer(@WndProcCallback));
    end;
    if not string.IsNullOrEmpty(ATip) and not string.IsNullOrWhiteSpace(ATip) then
    begin
      StrLCopy(notifyIconData.szTip, PChar(ATip), High(notifyIconData.szTip));
    end;
    Shell_NotifyIcon(NIM_ADD, @notifyIconData);
    bVisible := True;
  end;
end;

procedure TTrayIcon.Hide;
begin
  if bVisible then
  begin
    Shell_NotifyIcon(NIM_DELETE, @notifyIconData);
    bVisible := False;
  end;
end;

end.

