unit api.parrot.ardrone;

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Classes,
  IdBaseComponent, IdComponent, IdGlobal,
  IdUDPBase, IdUDPClient,
  IdTCPConnection, IdTCPClient;

type
  TDroneMovement = (
    Hover,
    MoveUp,
    MoveDown,
    MoveLeft,
    MoveRight,
    MoveForward,
    MoveBackward,
    RotateCW,
    RotateCCW
  );

  TLEDAnimation = (
    BlinkGreenRed,
    BlinkGreen,
    BlinkRed,
    BlinkOrange,
    SnakeGreenRed,
    Fire,
    Standard,
    Red,
    Green,
    RedSnake,
    Blank,
    RightMissile,
    LeftMissile,
    DoubleMissile,
    FrontLeftGreenOthersRed,
    FrontRightGreenOthersRed,
    RearRightGreenOthersRed,
    RearLeftGreenOthersRed,
    LeftGreenRightRed,
    LeftRedRightGreen,
    BlinkStandard);

  TDroneAnimation = (
    PhiM30Deg,
    Phi30Deg,
    ThetaM30Deg,
    Theta30Deg,
    Theta20degYaw200deg,
    Theta20degYawM200deg,
    Turnaround,
    TurnaroundGodown,
    YawShake,
    YawDance,
    PhiDance,
    ThetaDance,
    VZDance,
    Wave,
    PhiThetaMixed,
    DoublePhiThetaMixed,
    Mayday);

  TARDrone = class(TComponent)
  private
    udp: TIdUDPClient;
    navUdp: TIdUDPClient;

    seq: Integer;
    FGaz: Single;
    FTheta: Single;
    FYaw: Single;
    FPhi: Single;
    FOutdoor: Boolean;
    FFlightWithoutShell: Boolean;
    FConnect: TNotifyEvent;
    FDisconnect: TNotifyEvent;
    procedure UdpConnect(sender: TObject);
    procedure UdpDisconnet(sender: TObject);
    procedure SetGaz(const Value: Single);
    procedure SetPhi(const Value: Single);
    procedure SetTheta(const Value: Single);
    procedure SetYaw(const Value: Single);
    procedure SetOutdoor(const Value: Boolean);
    procedure SetFlightWithoutShell(const Value: Boolean);

    procedure ConnectNavData;
  protected
    { Protected declarations }
    procedure UpdateMovement;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Connect;
    procedure Disconnect;

    procedure SendCommand(cmd, arg: string);

    procedure RestrictAltitude(const Max: Integer); // between 500 to 5000
    procedure UnlimitedAltitude;
    procedure Config(const Key, Value: string);

    procedure RenameSSID(const SSID: string);
    procedure RenameDrone(const NewName: string);
    procedure AnimateLEDs(const Animation: TLEDAnimation; const FreqHz: Single; const DurationSeconds: Integer);

    procedure Takeoff;
    procedure Land;
    procedure Emergency;

    procedure FlatTrims; // Tell drone is is horizontal
    procedure Hover;
    procedure AnimateDrone(const Animation: TDroneAnimation; const DurationSeconds: Integer);

    procedure RotateCW(const yaw: Single = 1);
    procedure RotateCCW(const yaw: Single = 1);
    procedure MoveForward(const theta: Single = 1);
    procedure MoveBackward(const theta: Single = 1);
    procedure MoveLeft(const phi: Single = 1);
    procedure MoveRight(const phi: Single = 1);
    procedure MoveUp(const gaz: Single = 1);
    procedure MoveDown(const gaz: Single = 1);

    // Zero's the other movements
    procedure AnglularSpeed(const yaw: Single);
    procedure LeftRightAngle(const phi: Single);
    procedure FrontBackAngle(const theta: Single);
    procedure VerticalSpeed(const gaz: Single);

    // Full control of the movement (-1 to 1)
    procedure Move(const phi, theta, gaz, yaw: Single);

  published
    property Yaw: Single read FYaw write SetYaw;
    property Phi: Single read FPhi write SetPhi;
    property Theta: Single read FTheta write SetTheta;
    property Gaz: Single read FGaz write SetGaz;
    property Outdoor: Boolean read FOutdoor write SetOutdoor default False;
    property FlightWithoutShell: Boolean read FFlightWithoutShell write SetFlightWithoutShell default True;
    property OnConnect: TNotifyEvent read FConnect write FConnect;
    property OnDisconnect: TNotifyEvent read FDisconnect write FDisconnect;
  end;

function IEEEFloat(const aFloat: Single): Integer;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Gadgets', [TARDrone]);
end;

function IEEEFloat(const aFloat: Single): Integer;
type
  TIEEEFloat = record
    case Boolean of
      True: (Float: Single);
      False: (Int: Integer);
  end;
var
  Convert: TIEEEFloat;
begin
  Convert.Float := aFloat;
  Result := Convert.Int;
end;

{ TARDrone }

constructor TARDrone.Create;
begin
  inherited Create(AOwner);
  seq := 1;
  FOutdoor := True;
  FFlightWithoutShell := False;
end;

destructor TARDrone.Destroy;
begin
  if Assigned(udp) then
  try
    udp.Free;
  except
    udp := nil;
  end;
  if Assigned(navUdp) then
  try
    navUdp.Free;
  except
    navUdp := nil;
  end;
  inherited Destroy;
end;

procedure TARDrone.Connect;
begin
  if not Assigned(udp) then
  begin
    udp := TIdUDPClient.Create(nil);
    udp.OnConnected := UdpConnect;
    udp.OnDisconnected := UdpDisconnet;
    udp.Host := '192.168.1.1';
    udp.Port := 5556;
  end;

  udp.Connect;
  RestrictAltitude(2000);
  FlatTrims;

  // reduce NavData
  Config('general:navdata_demo','TRUE');
end;

procedure TARDrone.ConnectNavData;
var
  Buf: TIdBytes;
begin
  if not Assigned(NavUDP) then
  begin
    NavUDP := TIdUDPClient.Create(nil);
    NavUDP.Host := '192.168.1.1';
    NavUDP.Port := 5554;
    NavUDP.Connect;
    SetLength(Buf, 5);
    Buf[0] := 1;
    NavUDP.SendBuffer(buf);
  end;
end;

procedure TARDrone.Disconnect;
begin
  udp.Disconnect;
end;

procedure TARDrone.AnglularSpeed(const yaw: Single);
begin
  SendCommand('AT*PCMD',Format('1,0,0,0,%d', [IEEEFloat(yaw)]));
end;

procedure TARDrone.AnimateDrone(const Animation: TDroneAnimation;
  const DurationSeconds: Integer);
begin
  SendCommand('AT*ANIM', Format('%d,%d',
    [Ord(Animation), DurationSeconds]));
end;

procedure TARDrone.AnimateLEDs(const Animation: TLEDAnimation;
  const FreqHz: Single; const DurationSeconds: Integer);
begin
  SendCommand('AT*LED', Format('%d,%d,%d',
    [Ord(Animation), IEEEFloat(FreqHz), DurationSeconds]));
end;

procedure TARDrone.FlatTrims;
begin
  SendCommand('AT*FTROM','');
end;

procedure TARDrone.FrontBackAngle(const theta: Single);
begin
  SendCommand('AT*PCMD',Format('1,0,%d,0,0', [IEEEFloat(theta * -1)]));
end;

procedure TARDrone.Hover;
begin
  FGaz := 0;
  FTheta := 0;
  FYaw := 0;
  FPhi := 0;
  UpdateMovement;
end;

procedure TARDrone.LeftRightAngle(const phi: Single);
begin
  SendCommand('AT*PCMD',Format('1,%d,0,0,0', [IEEEFloat(phi * -1)]));
end;

procedure TARDrone.Move(const phi, theta, gaz, yaw: Single);
begin
  FGaz := gaz;
  FTheta := theta;
  FYaw := yaw;
  FPhi := phi;
  SendCommand('AT*PCMD',Format('1,%d,%d,%d,%d',
    [IEEEFloat(phi), IEEEFloat(theta), IEEEFloat(gaz), IEEEFloat(yaw)]));
end;

procedure TARDrone.MoveBackward(const theta: Single);
begin
  FrontBackAngle(-1 * theta);
end;

procedure TARDrone.MoveDown(const gaz: Single);
begin
  VerticalSpeed(-1 * gaz);
end;

procedure TARDrone.MoveForward(const theta: Single);
begin
  FrontBackAngle(theta);
end;

procedure TARDrone.MoveLeft(const phi: Single);
begin
  LeftRightAngle(phi);
end;

procedure TARDrone.MoveRight(const phi: Single);
begin
  LeftRightAngle(-1 * phi);
end;

procedure TARDrone.MoveUp(const gaz: Single);
begin
  VerticalSpeed(gaz);
end;

procedure TARDrone.RotateCCW(const yaw: Single);
begin
  AnglularSpeed(-1 * yaw);
end;

procedure TARDrone.RotateCW(const yaw: Single);
begin
  AnglularSpeed(yaw);
end;

procedure TARDrone.RenameDrone(const NewName: string);
begin
  Config('GENERAL:ardrone_name', NewName);
end;

procedure TARDrone.RenameSSID(const SSID: string);
begin
  Config('network:ssid_single_player', SSID);
end;

procedure TARDrone.Config(const Key, Value: string);
begin
  SendCommand('AT*CONFIG', Format('"%s","%s"', [key, value]));
end;

procedure TARDrone.RestrictAltitude(const Max: Integer);
var
  limit: Integer;
begin
  limit := Max;
  if limit < 500 then limit := 500;
  if limit > 5000 then limit := 5000;

  Config('control:altitude_max', IntToStr(limit));
end;

procedure TARDrone.SendCommand(cmd, arg: string);
var
  full: string;
begin
  if csDesigning in ComponentState then exit;
  if not assigned(udp) then exit;

  if not udp.Active then Connect;

  full := Format('%s=%d,%s' + Chr(13), [Cmd, Seq, arg]);
  Seq := Seq + 1;
  udp.Send(full);
end;

procedure TARDrone.SetFlightWithoutShell(const Value: Boolean);
begin
  FFlightWithoutShell := Value;
  Config('CONTROL:flight_without_shell', BoolToStr(Value, True));
end;

procedure TARDrone.SetGaz(const Value: Single);
begin
  FGaz := Value;
  UpdateMovement;
end;

procedure TARDrone.SetOutdoor(const Value: Boolean);
begin
  FOutdoor := Value;
  Config('CONTROL:outdoor', BoolToStr(Value, True));
end;

procedure TARDrone.SetPhi(const Value: Single);
begin
  FPhi := Value;
  UpdateMovement;
end;

procedure TARDrone.SetTheta(const Value: Single);
begin
  FTheta := Value;
  UpdateMovement;
end;

procedure TARDrone.SetYaw(const Value: Single);
begin
  FYaw := Value;
  UpdateMovement;
end;

procedure TARDrone.Takeoff;
begin
  SendCommand('AT*REF','290718208');
end;

procedure TARDrone.Emergency;
begin
  SendCommand('AT*REF','290717952');
end;

procedure TARDrone.Land;
begin
  SendCommand('AT*REF','290717696');
end;

procedure TARDrone.UdpConnect(sender: TObject);
begin
  if Assigned(FConnect) then
    FConnect(self);
end;

procedure TARDrone.UdpDisconnet(sender: TObject);
begin
  if Assigned(FDisconnect) then
    FDisconnect(self);
end;

procedure TARDrone.UnlimitedAltitude;
begin
  SendCommand('AT*CONFIG', '"control:altitude_max","10000"');
end;

procedure TARDrone.UpdateMovement;
begin
  Move(FPhi, FTheta, FGaz, FYaw);
end;

procedure TARDrone.VerticalSpeed(const gaz: Single);
begin
  SendCommand('AT*PCMD',Format('1,0,0,%d,0', [IEEEFloat(gaz)]));
end;

end.
