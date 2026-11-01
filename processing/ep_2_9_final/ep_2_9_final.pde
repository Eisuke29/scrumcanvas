import java.util.*; 
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator; 

// ---------- 設定 ----------
final int PLAYER_COUNT = 7;                // 9〜15の7人
final int[] JERSEY = {9,10,11,12,13,14,15};
final color FRIEND_BLUE = #1E90FF;         // 味方は青で統一
final float BALL_R = 5;                   // 選手球の半径

ArrayList<PVector>[] paths;  // 各選手の軌道（点列）
float[][] cums;              // 各選手の累積距離テーブル
float[] totals;              // 各選手の総距離

boolean isPlaying = false;   // 再生中か
float playSpeed = 0.5;       // 1フレームあたり進む距離（px/frame）
float distAlong = 0;         // 軌道上の再生位置（距離）
float totalLen = 0;          // 軌道の総距離

// ★ モード：true=描画フェーズ / false=再生(鑑賞)フェーズ
boolean drawMode = true;
// ★ 選択中の選手（描画対象）
int currentPlayer = 0;

// ★ オービットカメラ用（再生フェーズのみ使用）
float cx = 400, cz = 200, cy = 40;  // 注視点（地面中央ちょい上）
float yaw = PI/2;                  // 左右回転
float pitch = -PI/6;                // 上下回転（下向きがマイナス）
float radius = 400;                 // 注視点からの距離
int pmx, pmy;                       // 直前のマウス座標（回転用）
float playerHoverY = -BALL_R;     // 表示用の高さ（球を常に浮かせる）

int formation = 0;            // 0=Left, 1=Right, 2=Center
final String[] FORM_NAME = {"Left Scrum","Right Scrum","Center Scrum"};

// ラベル用スクリーン座標（毎フレーム更新）
float[] labelSX = new float[PLAYER_COUNT];
float[] labelSY = new float[PLAYER_COUNT];

// --- Ball & Pass ---
int ballOwner = 0;            // 初期保持者：9番
boolean ballInAir = false;    // 空中パス中か
int passTarget = -1;          // 受け手のインデックス
float passT = 0;              // パス進行 0→1
float passSpeed = 0.06;       // パスの速さ（tの増分/フレーム）
float passArc = 20;           // 放物線の高さ（px）
PVector passStart;            // 投げ始め位置

// ボールの見た目
final float BALL_SPHERE_R = 3;                 // ボール半径
final color BALL_COLOR = color(255, 240, 200);   // ボール色（薄いベージュ）

// --- Pass queue (manual trigger) ---
ArrayList<Integer> passQueue = new ArrayList<Integer>();
// 受け手の下1桁列（例: 9→0→2→5）
int passIdx = 0;  // 次に投げるキュー位置（0..size）

// 先頭の設定群の近くに追加
boolean shiftHeld = false; // Shiftが押されているか（確実に追跡）
boolean passEditMode = false; // オートパス編集モードか

boolean playEnded = false;   // ★ 再生が最後まで到達したか

// グローバル域に追加
int findPlayerByLastDigit(int d) 
{
  for (int i = 0; i < PLAYER_COUNT; i++) if (JERSEY[i] % 10 == d) return i;
  return -1;
}

// スクラブ用
boolean userScrubbing = false;
float   scrubT = 0;          // 0..1
int     tlX, tlY, tlW, tlH;  // タイムラインの矩形（毎フレーム更新）

// 先頭の設定群の近くに追加
final int BEATS = 8;           // 区間数
boolean timeMode = true;        // 時間ベース再生をデフォルトON
float   tPlay = 0;              // 現在のビート時刻[0..BEATS]
float   tSpeed = 0.03;          // 1フレームで進むビート量（＝再生速度）

float[][] markers;              // 各選手の時間マーカー（距離sを格納）長さ=BEATS+1

// ★ マーカー編集
boolean markerEdit = false;    // Mキーでトグル
int     selBeat    = -1;       // 選択中のビート index（0..BEATS）端は固定

// ---- Pass Marker 状態 ----
boolean passMarkerEdit = false;                // PでON/OFF
ArrayList<int[]> passPlan = new ArrayList<>(); // [passer, receiver] の列
int passMarkerIdx = 0;   
ArrayList<PassMarker> passMarkers = new ArrayList<PassMarker>();

// 攻撃方向（XZ平面、+X=右方向をデフォルト）
PVector ATTACK_DIR = new PVector(1, 0, 0);

// HUDメッセージ（簡易トースト）
String hudMsg = "";
int hudMsgTimer = 0;
void showMsg(String m){ hudMsg=m; hudMsgTimer=90; }

// --- Ball flight (beats-synced) ---
final float BALL_PX_PER_BEAT = 240; // 距離[px]をビートに換算する速度

// 再生中の自動パスに使う一時値
float passStartBeat = 0;      // このパスの投げ始め時刻（beat）
float passFlightBeats = 0;    // 飛行時間（beat）
PVector plannedCatchPos = null; // 受け取りの固定座標

boolean forwardRuleEnabled = false; // ← 一時的にオフ


// 追加：各選手のフォーメーション初期位置を保持
PVector[] basePos;  // ← new

// --- Mouse pick (player sphere / label) ---
final float PICK_R = 5;                 // 球ヒット判定半径(px)
float[] pickSX = new float[PLAYER_COUNT];  // 球中心のスクリーン座標
float[] pickSY = new float[PLAYER_COUNT];
float[] labelW = new float[PLAYER_COUNT];  // ラベルの描画サイズ
float[] labelH = new float[PLAYER_COUNT];

// --- Queue RECトグル（HUD上の小ボタン） ---
int recX=0, recY=0, recW=44, recH=20;   // クリック領域（毎フレ更新）

// --- Timeline click hit radius（Step4で可変にします） ---
final float TL_TICK_HIT  = 8;   // BEAT目盛りクリック判定半径(px)
final float TL_EVENT_HIT = 9;   // 投げイベントマーカーのクリック判定半径(px)

// --- Input routing ---
final float DRAG_THRESH  = 6;   // この距離以上動いたら「描画ドラッグ」開始

// この押下は描画ドラッグを許可するか？＆もう描画開始閾値を越えたか？
boolean canDrawDrag   = false;
boolean isDrawingDrag = false;

// ===== パス基準：データ構造 =====
class PassNode 
{
  int sender, receiver;
  PVector pos;
  float t;
  boolean isDummy;
  PassNode(int sender,int receiver,PVector pos,float t,boolean isDummy)
  {
    this.sender=sender;
    this.receiver=receiver;
    this.pos=pos.copy(); 
    this.t=t; this.isDummy=isDummy;
  }
  boolean isRealPass(){ return !isDummy && sender>=0 && receiver>=0; }

  float sSend = 0;   // 投げ距離
  float sRecv = 0;   // 受け距離

  // ★追加
  float flightBeats = 0; // 飛行時間[beats]
  float tThrow = 0;      // 投げる時刻[beats] (= t - flightBeats)
}

// === Defense (opponent) ===
final color ENEMY_RED = #E64A4A;

// 味方 index: 0:9, 1:10, 2:11, 3:12, 4:13, 5:14, 6:15
final int[] DEFENDER_IDX = {0, 1, 3, 4, 5}; // 9,10,12,13,14 だけ
final int   OPP_COUNT    = DEFENDER_IDX.length;

PVector[] oppPos;   // 上記5人の現在位置
int[]     markTo;   // 1:1 マーク（対応する味方 index）

// ライン位置・分離・速度（←必要に応じて数値だけ調整）
float DEF_LINE_Z   = 160; // ディフェンスラインは X 軸と平行、Z 固定
float DEF_SEP_X    = 36;  // X方向の最小間隔（重なり回避）
float DEF_SPEED    = 65;  // 1 beat あたりの最大移動量[px]（速いほど詰めが速い）
float DEF_SPEED_SCRUB_SNAP_BEATS = 0.25f; // スクラブ大移動時はスナップ閾値[beats]

// 後方カバー（11,15）
final boolean SHOW_BACKFIELD = true; // ← false にすると非表示
final int[]   BACK_IDX = {2, 6};     // 11, 15
PVector[]     backPos;               // 後方2人の現在位置
float         BACKFIELD_Z = 30;     // ラインより深く配置（Z 大きめ＝下側）
float         BACK_SPEED  = 80;     // 後方2人の追従速度[px/beat]

// スクラブ対応
float prevTPlay = 0;

// --- Defense (center scrum only) ---
final int   DEF_LINE_COUNT = 5;   // ライン上5人
final boolean SHOW_DEF_BACK11 = true;
final boolean SHOW_DEF_BACK15 = true;
final float BACK11_Z_OFFSET = 130; // 11番はラインより少し後ろ
final float BACK15_Z_OFFSET = 150; // 15番はさらに後ろ

PVector[] defPos = new PVector[DEF_LINE_COUNT]; // ラインDFの現在位置
float[]   defX   = new float[DEF_LINE_COUNT];   // そのX
int[]     defMark= new int[DEF_LINE_COUNT];     // 追尾対象(アタックindex)

PVector defBack11 = new PVector(400, -1.5, DEF_LINE_Z - BACK11_Z_OFFSET);
PVector defBack15 = new PVector(400, -1.5, DEF_LINE_Z - BACK15_Z_OFFSET);

// 到着アンカー（時刻 t と 距離 s）
class Anchor { float t,s; Anchor(float t,float s){ this.t=t; this.s=s; } }

// 比較器：時刻昇順
final Comparator<Anchor> BY_TIME = new Comparator<Anchor>()
{
  public int compare(Anchor a, Anchor b){ return Float.compare(a.t, b.t); }
};

// パスマーカー：クリックで置く「パサーの線上の位置」
// パスマーカー：1本のパスに対し、投げ位置と受け位置の両方を持つ
class PassMarker 
{
  int passIndex;    // 何本目のパスか（0-based）
  int passer;       // パサー index
  int receiver;     // レシーバー index
  Float sThrow = null; // パサー走路上の距離s（投げ位置）
  Float sCatch = null; // レシーバー走路上の距離s（受け位置）
  PassMarker(int passIndex, int passer, int receiver)
  {
    this.passIndex = passIndex;
    this.passer = passer;
    this.receiver = receiver;
  }
  boolean ready(){ return sThrow!=null && sCatch!=null; }
}

// パス進行・同期用
ArrayList<PassNode> nodes = new ArrayList<PassNode>();
ArrayList<Anchor>[] anchors; // 各選手のアンカー列
int playbackPassIdx = 0;      // 再生中に次に消化するノードindex

boolean waitingThrowClick = false; // 次のクリックが「投げ位置」か？
boolean waitingCatchClick = false; // 次のクリックが「受け位置」か？

// --- PassMarker placement tunables ---
float PASS_LINE_HIT_PX = 10;   // ラインからの許容距離[px]。超えると無効
boolean PASS_BACK_ONLY = true; // 受けは投げよりZが後ろ(小さい)のみ許可
float PASS_Z_EPS = 1.0;        // Z比較の許容誤差[px]

// 新: 全員OK
// 新: 全員OK → 15はライン対象外（後方カバーへ）
boolean isLineEligible(int idx)
{ 
  return JERSEY[idx] != 11; 
}


// --- FB15（フルバック）追従のチューニング ---
final float FB15_CENTER_X    = 400;  // 中央基準
final float FB15_CENTRAL_BIAS= 0.35; // 中央寄りバイアス(0=ボール全振り, 1=中央固定寄り)
final float FB15_DEADBAND    = 40;   // 中央近辺は動かない帯[px]
final float FB15_MIN_X       = 240;  // 動ける最小X（守備の幅を制限）
final float FB15_MAX_X       = 560;  // 動ける最大X
final float FB15_LEAD_X      = 20;   // 攻撃方向に少しだけ先読みオフセット
final float FB15_SPEED_SCALE = 0.70; // 11より少しゆっくり動かす倍率

// --- Scrum marker (simple oval) ---
float SCRUM_X = 200, SCRUM_Z = 200;  // 現在のスクラム中心（フォーメーションに連動）
final float SCRUM_RX = 15, SCRUM_RZ = 15;  // 楕円半径（X/Z）

// ラインDF用のZ基準値（初期は全員 DEF_LINE_Z）
float[] defZ = new float[DEF_LINE_COUNT];

// 後方DFのZオフセット（初期0）
float back11ZOffset = 0;
float back15ZOffset = 0;

// --- Z方向の微追従チューニング ---
float DEF_Z_FOLLOW     = 0.25;  // マーク相手のZ変化をどの割合で反映するか(0..1)
float DEF_Z_DRIFT_MAX  = 22;    // ライン基準からの最大ずれ[px]
float DEF_Z_SPEED      = 45;    // 1beatあたりのZ移動上限[px]

// 後方2人(11/15)用。もう少し自由度高め
float BACK_Z_FOLLOW    = 0.35;
float BACK_Z_DRIFT_MAX = 40;
float BACK_Z_SPEED     = 60;
float DEF_LINE_SAFE_MARGIN = 6; // ラインを越えないための余白

PFont hudFont;

void setup()
{
  size(800, 400, P3D);
  hudFont = createFont("NotoSansJP-SemiBold.ttf", 12, true);
  textMode(SHAPE);   // P3Dでの文字欠け対策
  surface.setLocation(displayWidth/2-400, displayHeight/2-200); 
  surface.setResizable(false);
  smooth();
  
  paths  = (ArrayList<PVector>[]) new ArrayList[PLAYER_COUNT];
  cums   = new float[PLAYER_COUNT][];
  totals = new float[PLAYER_COUNT];
  markers = new float[PLAYER_COUNT][];
  anchors = (ArrayList<Anchor>[]) new ArrayList[PLAYER_COUNT]; // ←追加
  basePos = new PVector[PLAYER_COUNT]; // ← 追加
  
  for (int i = 0; i < PLAYER_COUNT; i++)
  {
    paths[i] = new ArrayList<PVector>();
    cums[i] = null;
    totals[i] = 0;
  }
  applyFormation(formation);
  
    // 追加：敵の初期化
  oppPos = new PVector[OPP_COUNT];
  markTo = new int[OPP_COUNT];
  initOpponents();
  
   // ★起動時の保持者を9番に、パス状態クリア
  ballOwner = chooseInitialOwnerFromQueue();
  ballInAir = false;
  passTarget = -1;
}

void draw()
{
  background(200, 220, 255);
  //  カメラ
  if (drawMode)
  {
    camera(400, -350, 200, 400, 0, 200, 0, 0, 1);   // 俯瞰（up=Z）
  }
  else 
  {
    // オービット用：球面座標→デカルト
    pitch = constrain(pitch, -PI/2 + 0.1, -0.05);   // 下向きに限定
    radius = constrain(radius, 250, 1200);
    float ex = cx + radius * cos(pitch) * cos(yaw);
    float ey = cy + radius * sin(pitch);
    float ez = cz + radius * cos(pitch) * sin(yaw);
    camera(ex, ey, ez,  cx, 0, cz,  0, 1, 0);       // up=Y（通常）
  }
         
  ambientLight(80, 80, 80);                         // 全体底上げ
  directionalLight(220, 220, 220, -0.5, -1, -0.3);  // 斜め上から
  pointLight(255, 255, 200, 400, -300, 200);        // 追加の点光源(任意)
  specular(255);
  shininess(20);

  //地面
  pushMatrix();
  translate(400, 0, 200);
  fill(50, 180, 70);
  noStroke();
  box(800,1, 400);
  popMatrix();
  
  drawScrumMarker();
  
  // 黒い線
  stroke(0);
  strokeWeight(3);
  noFill();
  stroke(FRIEND_BLUE, 220);
  for (int k = 0; k < PLAYER_COUNT; k++)
  {
    beginShape();
    for (PVector p : paths[k]) vertex(p.x, p.y, p.z);
    endShape();
  }
  
  if (paths[currentPlayer].size() > 0) 
  {
    strokeWeight(5);
    beginShape();
    for (PVector p : paths[currentPlayer]) vertex(p.x, p.y, p.z);
    endShape();
  }
  
  boolean anyPlayable = false;
  for (int k = 0; k < PLAYER_COUNT; k++)
  {
    if (paths[k].size() >= 2)
    { 
      anyPlayable = true;
      break;
    }
  }
  
  // draw() 内
  if (isPlaying && anyPlayable)
  {
    tPlay += tSpeed;
    if (tPlay > BEATS) 
    {
      tPlay = BEATS;
      isPlaying = false;
      playEnded = true;
      if (ballInAir) { ballInAir = false; ballOwner = passTarget; passTarget = -1; }
    }
  }
  
    // 時間に基づく自動パス開始（nodesに基づく）
  if (isPlaying && !ballInAir && playbackPassIdx < nodes.size()) 
  {
    PassNode nd = nodes.get(playbackPassIdx);
    PVector sPos = posAt(nd.sender, nd.sSend);
    PVector rPos = posAt(nd.receiver, nd.sRecv);
  
    float tThrow = nd.tThrow;                 // ★ここを使用
    float flightBeats = max(1e-4, nd.flightBeats);
  
    if (tPlay >= tThrow)
    {
      // フォワードチェックは今は無効化でOK
      ballOwner = nd.sender;
      passTarget = nd.receiver;
      ballInAir = true;
  
      passStart = sPos.copy();
      plannedCatchPos = rPos.copy();
      passStartBeat = tThrow;                 // ★
      passFlightBeats = flightBeats;          // ★
  
      passT = 0;
      playbackPassIdx++;
    }
  }

  // 現在位置（再生中は軌道上、停止中は中央に浮かす）
  for(int k=0; k<PLAYER_COUNT; k++)
  {
    PVector pos = currentDisplayPos(k);
    
    pushMatrix();
    translate(pos.x, playerHoverY, pos.z);
    noStroke();
    fill(FRIEND_BLUE);
    sphere(BALL_R);
    popMatrix();
    
    float sx = screenX(pos.x, playerHoverY - (BALL_R + 14), pos.z);
    float sy = screenY(pos.x, playerHoverY - (BALL_R + 14), pos.z);
    labelSX[k] = sx; 
    labelSY[k] = sy;
    
    // ★追加：球中心のスクリーン座標（ヒットテスト用）
    pickSX[k] = screenX(pos.x, playerHoverY, pos.z);
    pickSY[k] = screenY(pos.x, playerHoverY, pos.z);
    
    // ★保持者の足元にパルスするリング
    if (k == ballOwner)
    {
      float pulse = 1.0 + 0.25 * sin(frameCount * 0.15); // 1.0±0.25
      pushMatrix();
      translate(pos.x, -1.5, pos.z);
      rotateX(HALF_PI);
      noFill();
      stroke(255, 210, 0, 220);
      strokeWeight(2);
      ellipse(0, 0, BALL_R * 5 * pulse, BALL_R * 5 * pulse);
      popMatrix();
    }
  }
   drawJerseyLabels();
   
   // 味方描画の直後あたりに追加：
  updateDefense(isPlaying ? tSpeed : 0);
  drawDefense();

   // --- Ball: 位置更新と描画 ---
  PVector ownerPos = currentDisplayPos(ballOwner);
  PVector ballPos;
  
  if (ballInAir)
  {
    if (plannedCatchPos != null && passFlightBeats > 0) 
    {
      // 拍ベースで進捗
      float u = constrain((tPlay - passStartBeat) / passFlightBeats, 0, 1);
      PVector flat = PVector.lerp(passStart, plannedCatchPos, u);
      float lift = -passArc * 4 * u * (1 - u);
      ballPos = new PVector(flat.x, playerHoverY + lift, flat.z);
  
      if (u >= 1.0)
      {
        ballInAir = false;
        ballOwner = passTarget;
        passTarget = -1;
        ballPos = new PVector(plannedCatchPos.x, playerHoverY, plannedCatchPos.z);
        plannedCatchPos = null;
        passFlightBeats = 0;
      }
    } 
    else 
    {
      // フォールバック（手動Tパスなど既存挙動）
      PVector recvPos = currentDisplayPos(passTarget);
      PVector flat = PVector.lerp(passStart, recvPos, passT);
      float lift = -passArc * 4 * passT * (1 - passT);
      ballPos = new PVector(flat.x, playerHoverY + lift, flat.z);
      passT += passSpeed;
      if (passT >= 1.0)
      {
        ballInAir = false;
        ballOwner = passTarget;
        passTarget = -1;
        ballPos = new PVector(recvPos.x, playerHoverY, recvPos.z);
      }
    }
  }
  else 
  {
    ballPos = new PVector(ownerPos.x, playerHoverY, ownerPos.z);
  }

  // ボールを描画
  pushMatrix();
  translate(ballPos.x, ballPos.y, ballPos.z);
  noStroke();
  fill(BALL_COLOR);
  sphere(BALL_SPHERE_R);
  popMatrix();

  // ★ マーカー編集ONなら、常に（停止・再生どちらでも）見せる
  if (markerEdit && drawMode) 
  {
    // 全選手表示（現在選手だけ強調）
    for (int k = 0; k < PLAYER_COUNT; k++) 
    {
      drawBeatMarkers(k, (k == currentPlayer) ? 1.0 : 0.35);
    }
  }
  
  // ★ 設置済みパスマーカーの可視化（紫の小さな球）
   // ★ 設置済みパスマーカーの可視化（投げ=紫 / 受け=オレンジ）
  for (PassMarker pm : passMarkers) 
  {
    if (pm == null) continue;
  
    // 投げ位置（パサーの線上）
    if (pm.sThrow != null)
    {
      if (cums[pm.passer] == null) ensureTablesFor(pm.passer);
      PVector p = posAt(pm.passer, pm.sThrow);
      pushMatrix();
      translate(p.x, playerHoverY, p.z);
      noStroke();
      fill(255, 0, 255); // 紫
      sphere(3);
      popMatrix();
    }
    // 受け位置（レシーバーの線上）
    if (pm.sCatch != null)
    {
      if (cums[pm.receiver] == null) ensureTablesFor(pm.receiver);
      PVector q = posAt(pm.receiver, pm.sCatch);
      pushMatrix();
      translate(q.x, playerHoverY, q.z);
      noStroke();
      fill(255, 140, 0); // オレンジ
      sphere(3);
      popMatrix();
    }
  }
  // 画面右上にヘルプ表示
  hintText();
}

void mousePressed()
{
  pmx = mouseX;
  pmy = mouseY;
    
  // パスマーカー編集中：クリックで1個設置
  if (passMarkerEdit)
  {
    placePassMarkerWithClick(mouseX, mouseY);
    return;
  }
  
  if (mouseX >= recX && mouseX <= recX+recW && mouseY >= recY && mouseY <= recY+recH)
  {
    passEditMode = !passEditMode;
    showMsg(passEditMode ? "Queue REC: ON" : "Queue REC: OFF");
    canDrawDrag = false; 
    isDrawingDrag = false;
    return;
  }

  int hit = pickPlayerAt(mouseX, mouseY);
  if (hit != -1) 
  {
    if (passEditMode) 
    {
      // キュー編集モード中はクリックした選手をQueueに追加
      passQueue.add(JERSEY[hit] % 10);
      showMsg("Queue += " + JERSEY[hit]);
    }
    
    if (drawMode && shiftHeld) {
      currentPlayer = hit;                // ついでに選手も確定
      canDrawDrag = true;                 // ← ドラッグ許可
      isDrawingDrag = false;              // 閾値超えで開始
      return;                             // 以降の「選択だけ」処理はスキップ
    }
    // 通常は選手選択
    currentPlayer = hit;
    showMsg("Select: " + JERSEY[hit]);
    canDrawDrag = false; 
    isDrawingDrag = false;
    return;
  }

  if (hitTimeline(mouseX, mouseY))
  {
    // 1) 投げイベントマーカー（tThrow）にヒット？
    float tHit = Float.NaN;
    if (nodes != null)
    {
      for (int i = 0; i < nodes.size(); i++) 
      {
        PassNode nd = nodes.get(i);
        int x = (int)(tlX + tlW * (nd.tThrow / (float)BEATS));
        if (abs(mouseX - x) <= TL_EVENT_HIT) { tHit = nd.tThrow; break; }
      }
    }
    // 2) 見つからなければ BEAT 目盛りにヒット？
    if (Float.isNaN(tHit)) 
    {
      for (int b = 0; b <= BEATS; b++) 
      {
        int x = (int)(tlX + tlW * (b / (float)BEATS));
        if (abs(mouseX - x) <= TL_TICK_HIT) { tHit = b; break; }
      }
    }
    // 3) いずれかにヒット → ジャンプして自動再生
    if (!Float.isNaN(tHit)) 
    {
      tPlay = constrain(tHit, 0, BEATS);
      recalcPlaybackStateFromTime(tPlay);
      isPlaying = true;      // クリック後は自動再生
      canDrawDrag = false;
      isDrawingDrag = false;
      return;
    }
    // 4) ヒットなし → スクラブ開始
    userScrubbing = true;
    setScrubFromMouse(mouseX);
    canDrawDrag = false; 
    isDrawingDrag = false;
    return;
  }
  
  if (shiftHeld && hitTimeline(mouseX, mouseY))
 {
    userScrubbing = true;
    setScrubFromMouse(mouseX);
    return;
  }
  
  if (markerEdit && drawMode)
  {
    // 近いビートを拾う（スクリーン座標で判定）
    int k = currentPlayer;
    ensureTablesFor(k);
    selBeat = -1;
    float best = 1e9;
    for (int i=0; i<=BEATS; i++) 
    {
      PVector p = posAt(k, markers[k][i]);
      float sx = screenX(p.x, playerHoverY, p.z);
      float sy = screenY(p.x, playerHoverY, p.z);
      float d2 = sq(mouseX - sx) + sq(mouseY - sy);
      if (d2 < best && d2 < sq(12)) 
      { // 12px 以内
      best = d2; selBeat = i;
      }
    }
    canDrawDrag = false;
    isDrawingDrag = false;
    return;
  }
  
  canDrawDrag = drawMode;
  isDrawingDrag = false;
}

void mouseDragged() 
{
  if (!drawMode && mouseButton == RIGHT)
  {
    float dx = mouseX - pmx;
    float dy = mouseY - pmy;
    yaw   += dx * 0.01;
    pitch += dy * 0.01;
    pmx = mouseX; pmy = mouseY;
    return;
  }
  
  if (userScrubbing)
  { 
    setScrubFromMouse(mouseX);
    return; 
  }
  
  if (passMarkerEdit)
  {
    // （必要ならここで「鑑賞モード中の右ドラッグ回転」は許可してもOK）
    return;
  }
  
  // ① マーカー編集中のドラッグを最優先
  if (markerEdit && drawMode) 
  {
     // 選択済みマーカーだけ動かす（端は固定）
     if (selBeat > 0 && selBeat < BEATS)
     {
       // 距離テーブルが消えている可能性に備えて保証
       if (cums[currentPlayer] == null || markers[currentPlayer] == null)
       {
         buildCumulativeAll();
       }
       float s = mouseToPathS(currentPlayer);
       float left  = markers[currentPlayer][selBeat-1] + 0.5;
       float right = markers[currentPlayer][selBeat+1] - 0.5;
       markers[currentPlayer][selBeat] = constrain(s, left, right);
       normalizeMarkers(currentPlayer);
     }
     return; // ← マーカー編集時は他の処理を食い止める
   }
   
   // ★ここから「描画ドラッグ」のガード
  if (!canDrawDrag) return;           // 選手/タイムラインなどを押して始まったら描画不可
  if (!isDrawingDrag) 
  {
    if (dist(mouseX, mouseY, pmx, pmy) < DRAG_THRESH) return;  // クリック誤作動防止
    isDrawingDrag = true;                         // 閾値越えたので描画開始
  }
   
   // ② 通常の描画ドラッグ（markerEdit ではないときだけ有効）
   if (drawMode)
   {
     if (shiftHeld) 
     {
       if (JERSEY[currentPlayer] == 9) 
       {
          showMsg("9番はShiftドラッグで初期位置を動かせません");
          return;
        }
       
        PVector p = new PVector(mouseX, -1.5, mouseY);
        if (paths[currentPlayer].size() == 0) paths[currentPlayer].add(p);
        else paths[currentPlayer].set(0, p);
        cums[currentPlayer]    = null;
        totals[currentPlayer]  = 0;
        markers[currentPlayer] = null;
      } 
      else 
      {
        paths[currentPlayer].add(new PVector(mouseX, -1.5, mouseY));
        cums[currentPlayer]    = null;
        totals[currentPlayer]  = 0;
        markers[currentPlayer] = null;
      }
      return;
    }
}

void mouseReleased() 
{
  if (userScrubbing) userScrubbing = false;
  if (markerEdit) selBeat = -1;
  canDrawDrag = false;
  isDrawingDrag = false;
}

void keyPressed() 
{
  if (key == CODED && keyCode == SHIFT) { shiftHeld = true; return; }

  if (key == 'r' || key == 'R')
  {
    clearAll();
    return;
  }
  
  else if (key == ' ') 
  {
    // パスマーカー本数の一致だけでなく、各マーカーが両端点 ready か確認
    if (passMarkers.size() != passPlan.size()) { return; }
    for (PassMarker pm : passMarkers) { if (pm==null || !pm.ready()) return; }
  
    // 走路テーブルを最新化
    buildCumulativeAll();
  
    // ノードとアンカーを構築
    ballInAir = false; passTarget = -1;
    ballOwner = chooseInitialOwnerFromQueue(); 
    buildNodesFromPassMarkers();
    rebuildAnchorsFromNodes();
    addTempoAnchorsForPassersOnly();  
    
    resetDefenseForReplay();
  
    // 再生準備
    playbackPassIdx = 0;
    tPlay = 0;
    isPlaying = true;
    drawMode = false;
    plannedCatchPos = null;
    passFlightBeats = 0;
    return;
  }

  else if (key == '+' || key == '=') 
  {
    playSpeed += 0.5;
    return;
  } 
  else if (key == '-' || key == '_') 
  {
    playSpeed = max(0.5, playSpeed - 0.5);
    return;
  }
  else if (key == TAB)
  {
    drawMode = !drawMode; // ★ 手動でモード切替
    return;
  } 
  else if (key == '[')
  {
    radius += 30;             // ★ ズームアウト
    return;
  }
  else if (key == ']')
  {
    radius -= 30;             // ★ ズームイン
    return;
  }
  
  // --- 鑑賞カメラ角度（矢印キー） ---
  if (keyCode==LEFT){  yaw -= 0.05; return; }
  if (keyCode==RIGHT){ yaw += 0.05; return; }
  if (keyCode==UP){    pitch -= 0.04; return; }
  if (keyCode==DOWN){  pitch += 0.04; return; }
    
  // --- 初期配置：Left/Right/Center 直接指定 ---
  if (key=='l'||key=='L'){ applyFormation(0); return; }
  if (key=='v'||key=='V'){ applyFormation(1); return; } 
  if (key=='c'||key=='C'){ applyFormation(2); return; }

  // 既存の Backspace/Delete の分岐を置換
  // keyPressed() 内の BACKSPACE/DELETE 分岐を置換
  if (keyCode == BACKSPACE || keyCode == DELETE)
  {
    if (passEditMode)
    {
      if (!passMarkers.isEmpty()) passMarkers.remove(passMarkers.size()-1);
      else if (!passQueue.isEmpty()) passQueue.remove(passQueue.size()-1);
    }
    else 
    {
      int k = currentPlayer;
      paths[k].clear();
      // ★初期フォーメーション位置を復元（中央に飛ばない）
      if (basePos != null && basePos[k] != null)
      {
        paths[k].add(basePos[k].copy());
      } 
      else 
      {
        // 念のためのフォールバック（まず起きない想定）
        paths[k].add(new PVector(400, -1.5, 200));
      }
      cums[k] = null;
      totals[k] = 0;
      markers[k] = null;
      showMsg("走路をクリア：初期位置は維持");
    }
    return;
  }
  

  // ★ T：キューの次に投げる（再生中＆空中でない時のみ）
  if (key=='t' || key=='T')
  {
    if (!isPlaying || ballInAir) return;  // 再生中＆空中でない時だけ
    int targetIdx = -1;
  
    // キュー先頭から「不正/自分」をスキップ
    while (passIdx < passQueue.size())
    {
      int d = passQueue.get(passIdx);
      int idx = findPlayerByLastDigit(d);
      if (idx == -1 || idx == ballOwner) 
      { // 不正 or 自分
        passIdx++;
        continue;
      }
      targetIdx = idx;
      break;
    }
  
    // フォールバック：有効な相手が見つからない→選択中へ
    if (targetIdx == -1 && currentPlayer != ballOwner)
    {
      targetIdx = currentPlayer;
    }
  
    if (targetIdx != -1 && paths[targetIdx].size() > 0) 
    {
      startPassTo(targetIdx);
      if (passIdx < passQueue.size()) passIdx++;  // 成功時のみキュー進行
    }
    return;
  }
  
  if (keyCode == ENTER)
  {
    passIdx = 0;
    if (passEditMode) passEditMode = false;
    return;
  }
  
  // マーカー編集トグル
  else if (key=='m'||key=='M')
  {
    /*
    markerEdit = !markerEdit;
    selBeat = -1;
    buildCumulativeAll();    // markers の存在を保証
    */
    return;
  }
  
  else if (key=='p' || key=='P')
  {
    passMarkerEdit = !passMarkerEdit;
    if (passMarkerEdit)
    {
      buildPassPlanFromQueue();
      buildCumulativeAll(); 
      passMarkerIdx = 0;
      passMarkers.clear();
      nodes.clear();
      waitingThrowClick = true;
      waitingCatchClick = false;
  
      if (!passPlan.isEmpty()) {
        int sIdx = passPlan.get(0)[0];
        showMsg("PASS-MARKER: 投げ位置をクリック（" + JERSEY[sIdx] + " の線上）");
      } 
      else
      {
        showMsg("キューが空です。Gでキュー編集→Pでマーカー");
      }
    }
    return;
  }
}

// keyReleased() を新規追加
void keyReleased()
{
  if (key == CODED && keyCode == SHIFT) shiftHeld = false;
}

void startPlayback()
{
  tPlay = 0;                 // 時間ベースは0ビートから
  distAlong = 0;             // 距離ベースも念のため0
  isPlaying = true;
  playEnded = false;

  // 再生可能な軌道があるかチェック
  boolean any = false;
  for (int i = 0; i < PLAYER_COUNT; i++) 
  {
    if (paths[i].size() >= 2) 
    {
      any = true; 
      break;
    }
  }
  if (!any) return;

  buildCumulativeAll();
  distAlong = 0;
  isPlaying = true;
  drawMode = false;
    
  passIdx = 0; // 再生開始時は先頭から
  
  // startPlayback() の末尾に追加
  alignPassCursorToOwner();
  playEnded = false;
}

boolean hitTimeline(int mx, int my) 
{
  return (mx >= tlX && mx <= tlX + tlW && my >= tlY && my <= tlY + tlH);
}

void setScrubFromMouse(int mx) 
{
  scrubT = constrain(map(mx, tlX, tlX + tlW, 0, 1), 0, 1);
  tPlay  = scrubT * BEATS;
  isPlaying = false;           // ドラッグ中は一時停止
  recalcPlaybackStateFromTime(tPlay);
}

void alignPassCursorToOwner()
{
  int ownerD = JERSEY[ballOwner] % 10;
  passIdx = 0;
  // まず最初に出てくる「現保持者の下1桁」の直後へカーソルを置く
  for (int i = 0; i < passQueue.size(); i++)
  {
    if (passQueue.get(i) == ownerD) { passIdx = i + 1; break; }
  }
  // さらに不正/自分自身をスキップ
  while (passIdx < passQueue.size()) 
  {
    int idx = findPlayerByLastDigit(passQueue.get(passIdx));
    if (idx != -1 && idx != ballOwner) break;
    passIdx++;
  }
}


void buildCumulativeAll()
{
  totalLen = 0;
  for (int k = 0; k < PLAYER_COUNT; k++) 
  {
    int n = paths[k].size();
    if (n < 2) { cums[k] = null; totals[k] = 0; continue; 
  }

    cums[k] = new float[n];
    cums[k][0] = 0;
    for (int i = 1; i < n; i++) 
    {
      cums[k][i] = cums[k][i-1] + PVector.dist(paths[k].get(i-1), paths[k].get(i));
    }
    totals[k] = cums[k][n-1];
    if (totals[k] > totalLen)
    {
      totalLen = totals[k]; // 全体の停止距離＝最長
    }
  }
  buildMarkersAll();
}

// 置換：buildMarkersAll()
void buildMarkersAll()
{
  for (int k = 0; k < PLAYER_COUNT; k++)
  {
    int m = BEATS + 1;
    if (paths[k].size() < 2) 
    { 
      markers[k] = null; 
      continue; 
    }
    // markers が未作成 or 長さが違うときだけ初期化
    if (markers[k] == null || markers[k].length != m)
    {
      markers[k] = new float[m];
      float L = totals[k];
      for (int i = 0; i < m; i++) 
      {
        markers[k][i] = (m > 1) ? L * i / (m - 1) : 0;
        // 既存の形を保ったまま、端点を保証
        markers[k][0] = 0;
        markers[k][m-1] = totals[k];
      }
    }
    else 
    {
      // 形は保って総距離だけ合わせる（比率スケール）
      float oldMax = markers[k][m - 1];
      float newMax = totals[k];
      if (oldMax > 0 && newMax > 0 && abs(oldMax - newMax) > 1e-3) 
      {
        float sf = newMax / oldMax;
        for (int i = 0; i < m; i++) markers[k][i] *= sf;
      }
    }
  }
}

// 追加：個別に距離表とマーカーを用意
void ensureTablesFor(int k) 
{
  if (paths[k].size() < 2) return;

  // 距離テーブルだけ個別で再計算
  int n = paths[k].size();
  if (cums[k] == null || cums[k].length != n) 
  {
    cums[k] = new float[n];
    cums[k][0] = 0;
    for (int i = 1; i < n; i++) {
      cums[k][i] = cums[k][i-1] + PVector.dist(paths[k].get(i-1), paths[k].get(i));
    }
    totals[k] = cums[k][n-1];
  }
  // マーカーは「無い/長さ違い」のときだけ初期化。既存は保持
  int m = BEATS + 1;
  if (markers[k] == null || markers[k].length != m) {
    markers[k] = new float[m];
    float L = totals[k];
    for (int i = 0; i < m; i++) {
      markers[k][i] = (m > 1) ? L * i / (m - 1) : 0;
    }
  }
}

// 指定選手kの距離dに対応する位置（線形補間）
PVector posAt(int k, float d) 
{
  ArrayList<PVector> path = paths[k];
  float[] cum = cums[k];
  float total = totals[k];

  if (path.size() == 0) return new PVector(400, 0, 200);
  if (path.size() == 1 || cum == null) return path.get(0).copy();

  if (d <= 0) return path.get(0).copy();
  if (d >= total) return path.get(path.size()-1).copy();

  // cum[i-1] < d <= cum[i] を探す
  int i = 1;
  while (i < cum.length && cum[i] < d) i++;

  float segStartDist = cum[i-1];
  float segLen = cum[i] - segStartDist;
  float t = (segLen == 0) ? 0 : (d - segStartDist) / segLen;

  PVector a = path.get(i-1);
  PVector b = path.get(i);
  return PVector.lerp(a, b, t);
}

// index k の「いま表示している位置」を返す（再生中は補間、停止中は最後の点）
// currentDisplayPos(int k) を置換
PVector currentDisplayPos(int k) 
{
  if (paths[k].size() >= 2)
  {
    if (cums[k] == null) ensureTablesFor(k);
    float t = constrain(tPlay, 0, BEATS);

    // 1) パスマーカーから生成されたアンカーがあれば最優先
    if (anchors[k] != null && anchors[k].size() >= 2) 
    {
      float s = sAtTimeUsingAnchors(k, t);
      s = constrain(s, 0, totals[k]);
      return posAt(k, s);
    }

    // 2) 既存のビートマーカー（従来のM）←使わなくてもフォールバックで残す
    if (markers[k] != null) 
    {
      int seg = constrain((int)floor(t), 0, BEATS-1);
      float a = t - seg;
      float s = lerp(markers[k][seg], markers[k][seg+1], a);
      return posAt(k, s);
    }

    // 3) 何も無いときは等速
    float sUni = totals[k] * (t / BEATS);
    return posAt(k, sUni);
  }
  if (paths[k].size() > 0) return paths[k].get(paths[k].size()-1).copy();
  return new PVector(400, 0, 200);
}

// 選手 targetIdx にパスを開始
void startPassTo(int targetIdx)
{
  if (targetIdx < 0 || targetIdx >= PLAYER_COUNT || targetIdx == ballOwner) return;
  PVector sPos = currentDisplayPos(ballOwner);
  PVector rPos = currentDisplayPos(targetIdx);
  if (isForwardPass(sPos, rPos)) {
    showMsg("FORWARD PASS — blocked");
    return;
  }
  passTarget = targetIdx;
  ballInAir = true;
  passT = 0;
  passStart = sPos.copy();
}

void clearAll()
{
  for (int i=0;i<PLAYER_COUNT;i++)
  {
    paths[i].clear(); cums[i]=null; totals[i]=0;
  }
  isPlaying=false; 
  distAlong=0; 
  totalLen=0; 
  drawMode=true;
  applyFormation(formation);
  
  // ★リセット時も9番が保持、パス状態クリア
  ballOwner = chooseInitialOwnerFromQueue();
  ballInAir = false;
  passTarget = -1;
  
  passIdx = 0; // リセット時も先頭から（キュー自体は残す）
  alignPassCursorToOwner();
  playEnded = false;
  
  // ★ 追加でパス関係もクリア
  passMarkers.clear();
  passPlan.clear();
  nodes.clear();
  playbackPassIdx = 0;
  passMarkerIdx = 0;
  passMarkerEdit = false;
  anchors = (ArrayList<Anchor>[]) new ArrayList[PLAYER_COUNT];
  
}

void applyFormation(int mode)
{
  formation = mode;
  
  if (mode == 0)
  {        
    // Left
    SCRUM_X = 150; SCRUM_Z = 200;
  }
  else if (mode == 1) 
  { 
    // Right
    SCRUM_X = 650; SCRUM_Z = 200;
  } 
  else 
  {             
    // Center
    SCRUM_X = 400; SCRUM_Z = 200;
  }

  
  // Left基準を定義してから、Rightは左右反転 / Centerは中央調整
  PVector[] left = new PVector[PLAYER_COUNT];

  // 座標系：X(0..800) 左→右、Z(0..400) 上→下。Y=0が地面、高さは-値で上方向。
  float scrumX = 200, scrumZ = 200;

  // インデックス: 0:9, 1:10, 2:11, 3:12, 4:13, 5:14, 6:15
  left[0] = new PVector(scrumX-50,-1.5, scrumZ+20); // 9 SH：スクラム後方
  left[1] = new PVector(scrumX+50, -1.5, scrumZ+75); // 10 SO：やや後方中央
  left[3] = new PVector(scrumX+150, -1.5, scrumZ+100 ); // 12 IC：SOの外側
  left[4] = new PVector(scrumX+250, -1.5, scrumZ+100 ); // 13 OC：さらに外側
  left[2] = new PVector(scrumX+100, -1.5, scrumZ+150 ); // 11 Blind Wing：左短辺側
  left[5] = new PVector(scrumX+450, -1.5, scrumZ+150 ); // 14 Open Wing：右大外
  left[6] = new PVector(scrumX+350,  -1.5, scrumZ+150 ); // 15 FB：少し後ろ

  PVector[] pos = new PVector[PLAYER_COUNT];
  if (mode==0)
  { // Left
    for (int k=0;k<PLAYER_COUNT;k++) pos[k] = left[k].copy();
  }
  else if (mode==1)
  { // Right：左右反転（フィールド中央x=400でミラー）
    for (int k=0;k<PLAYER_COUNT;k++)
    {
      float mx = 800 - left[k].x;
      pos[k] = new PVector(mx, -1.5, left[k].z);
    }
  } 
  else
  { // Center
    float cx0 = 400, cz0 = 200;
    pos[0] = new PVector(cx0, -1.5, cz0 +20   ); // 9
    pos[1] = new PVector(cx0-100, -1.5, cz0+50 ); // 10
    pos[3] = new PVector(cx0+250,-1.5, cz0+100 ); // 15
    pos[4] = new PVector(cx0-200,-1.5, cz0+100 ); // 13
    pos[2] = new PVector(cx0,-1.5, cz0 +150 ); // 11
    pos[5] = new PVector(cx0-300,-1.5, cz0+100  ); // 14
    pos[6] = new PVector(cx0+100, -1.5, cz0+50 ); // 12
  }

  // 既存の軌道を初期点だけに置き換える（配置をやり直すため）
  for (int k=0;k<PLAYER_COUNT;k++)
  {
    basePos[k] = pos[k].copy();   
    paths[k].clear();
    paths[k].add(pos[k]);
    cums[k]=null; totals[k]=0;
    markers[k] = null;
  }
  
  // 攻撃方向更新：Left/Centreは右(+X)、Rightは左(-X)に攻める想定
  if (formation == 1) ATTACK_DIR.set(-1, 0, 0);
  else                ATTACK_DIR.set( 1, 0, 0);
  
    // 追加：配置や走路が変わったら敵もリセット
  if (oppPos == null) oppPos = new PVector[OPP_COUNT];
  if (markTo == null) markTo = new int[OPP_COUNT];
  initOpponents();
  
  // …既存の攻撃側の初期化が終わった最後に
  if (formation == 0)
  {          
    // Left Scrum（+X がオープン）
    initDefenseForScrum(+1);
  }
  else if (formation == 1)
  {   
    // Right Scrum（-X がオープン）
    initDefenseForScrum(-1);
  } 
  else
  {                       
    // Center は従来
    initDefenseForCenter();
  }
  shiftClosestDefenseZ(+20);
  prevTPlay = tPlay;
}

void drawJerseyLabels()
{
  // 2D HUDに切替
  hint(DISABLE_DEPTH_TEST);
  pushStyle(); 
  pushMatrix();
  resetMatrix(); 
  camera();  
  noLights();
  textFont(hudFont, 12);
  textSize(12);
  // textFont(hudFont, 14); // 必要なら有効化
  textAlign(CENTER, CENTER);

  for (int k=0;k<PLAYER_COUNT;k++)
  {
    String t = str(JERSEY[k]);
    float w = max(18, textWidth(t)+8);
    // 選手番号の背景（半透明ダーク）
    noStroke();
    color bg = (k == ballOwner) ? color(255, 200, 0, 220) : color(0, 170);
    fill(bg);
    rectMode(CENTER);
    rect(labelSX[k], labelSY[k], w, 18, 6);
    // 番号（白）
    fill(255); 
    text(t, labelSX[k], labelSY[k]+0.5);
    labelW[k] = w;
    labelH[k] = 18;
  }

  popMatrix();
  popStyle();
  hint(ENABLE_DEPTH_TEST);
}

int chooseInitialOwnerFromQueue()
{
  for (int i = 0; i < passQueue.size(); i++)
  {
    int d = passQueue.get(i);
    int idx = findPlayerByLastDigit(d);
    if (idx != -1) return idx;  // 最初に見つかった有効な選手
  }
  return 0; // フォールバックは9番(index 0)
}
// 追加関数：マーカーを可視化（端=半透明、選択=強調）
void drawBeatMarkers(int k, double emphasis)
{
  if (markers[k]==null) return;
  if (cums[k]==null) ensureTablesFor(k); // 保険

  float a = (float)emphasis; // 1.0=強, 0.35=薄

  for (int i=0; i<=BEATS; i++)
  {
    PVector p = posAt(k, markers[k][i]);
    pushMatrix();
    translate(p.x, playerHoverY, p.z);
    noStroke();
    if (i==0 || i==BEATS)      fill(255, 120*a);     // 端は半透明
    else if (i==selBeat && k==currentPlayer) fill(255, 200, 0); // 選択中のみ強調色
    else                       fill(255, 255*a);
    sphere(2.5);
    popMatrix();
  }
}

// マウス(XZ)を、currentPlayer のポリライン上の距離 s に射影
float mouseToPathS(int k)
{
  ArrayList<PVector> path = paths[k];
  if (path.size() < 2) return 0;
  float bestD2 = 1e12;
  float bestS  = 0;
  float acc    = 0; // ここまでの距離
  for (int i=1; i<path.size(); i++) 
  {
    PVector A = path.get(i-1), B = path.get(i);
    float ax = A.x, az = A.z, bx = B.x, bz = B.z;
    float vx = bx - ax, vz = bz - az;
    float segLen = sqrt(vx*vx + vz*vz);
    if (segLen == 0) continue;
    float t = ((mouseX-ax)*vx + (mouseY-az)*vz) / (segLen*segLen);
    t = constrain(t, 0, 1);
    float px = ax + vx*t, pz = az + vz*t;
    float d2 = sq(mouseX - px) + sq(mouseY - pz);
    if (d2 < bestD2) { bestD2 = d2; bestS = acc + segLen*t; }
    acc += segLen;
  }
  return bestS;
}

void normalizeMarkers(int k) 
{
  if (markers[k] == null) return;
  int m = BEATS + 1;
  // 端点は 0 と 総距離 に固定
  markers[k][0]     = 0;
  markers[k][m - 1] = totals[k];
  // 前向きパス：右隣より 0.5 未満にはならない
  for (int i = 1; i < m; i++) markers[k][i] = max(markers[k][i], markers[k][i-1] + 0.5);
  // 後ろ向きパス：左隣より 0.5 超にはならない
  for (int i = m - 2; i >= 0; i--) markers[k][i] = min(markers[k][i], markers[k][i+1] - 0.5);
  // 念のため再固定
  markers[k][0]     = 0;
  markers[k][m - 1] = totals[k];
}

// i本目のパスのパサー
int passerFor(int i)
{
  if (i==0) return chooseInitialOwnerFromQueue();
  int prevRecv = findPlayerByLastDigit(passQueue.get(i-1));
  return prevRecv;
}

// i本目のパスの受け手
int receiverFor(int i)
{
  return findPlayerByLastDigit(passQueue.get(i));
}

// 任意点posを選手kのポリラインに射影して距離s（XZ）
float projectPointToPathS(int k, PVector pos)
{
  ArrayList<PVector> path = paths[k];
  if (path.size()<2) return 0;
  float bestD2=1e12f,bestS=0,acc=0;
  for(int i=1;i<path.size();i++)
  {
    PVector A=path.get(i-1),B=path.get(i);
    float ax=A.x, az=A.z, bx=B.x, bz=B.z;
    float vx=bx-ax, vz=bz-az;
    float segLen2 = vx*vx + vz*vz;
    
    if (segLen2==0) { continue; }
    
    float t = ((pos.x-ax)*vx + (pos.z-az)*vz)/segLen2;
    t = constrain(t,0,1);
    float px=ax+vx*t, pz=az+vz*t;
    float d2 = sq(pos.x-px)+sq(pos.z-pz);
    if (d2<bestD2){ bestD2=d2; bestS=acc+sqrt(segLen2)*t; }
    acc += sqrt(segLen2);
  }
  return bestS;
}

// nodes -> anchors を構築
void rebuildAnchorsFromNodes()
{
  // 初期化
  for(int k=0;k<PLAYER_COUNT;k++)
  {
    anchors[k] = new ArrayList<Anchor>();
    if (paths[k].size()>=2)
    {
      ensureTablesFor(k);
      anchors[k].add(new Anchor(0,0));
      anchors[k].add(new Anchor(BEATS, totals[k]));
    }
  }
  for (PassNode nd : nodes)
  {
    if (nd.sender>=0 && paths[nd.sender].size()>=2)
    {
      anchors[nd.sender].add(new Anchor(nd.tThrow, nd.sSend));   // ★投げ時刻
    }
    if (nd.receiver>=0 && paths[nd.receiver].size()>=2)
    {
      anchors[nd.receiver].add(new Anchor(nd.t, nd.sRecv));      // 受けは従来どおりキャッチ時刻
    }
  }
  // ソート・端点保証・単調化
  for (int k=0;k<PLAYER_COUNT;k++)
  {
    ArrayList<Anchor> ak = anchors[k];
    if (ak==null || ak.isEmpty()) continue;
    Collections.sort(ak, BY_TIME);
    if (abs(ak.get(0).t-0)>1e-6) ak.add(0,new Anchor(0,0));
    if (abs(ak.get(ak.size()-1).t-BEATS)>1e-6) ak.add(new Anchor(BEATS, totals[k]));
    Collections.sort(ak, BY_TIME);
    ak.get(0).s = 0;
    for (int i=1;i<ak.size();i++)
    {
      ak.get(i).s = max(ak.get(i).s, ak.get(i-1).s + 0.1);
      ak.get(i).s = min(ak.get(i).s, totals[k]);
    }
    ak.get(ak.size()-1).s = totals[k];
  }
}

// アンカーから s(t) を補間
float sAtTimeUsingAnchors(int k, float t)
{
  ArrayList<Anchor> a = anchors[k];
  if (a==null || a.size()==0) return 0;
  if (a.size()==1) return a.get(0).s;
  if (t<=a.get(0).t) return a.get(0).s;
  if (t>=a.get(a.size()-1).t) return a.get(a.size()-1).s;
  for (int i=1;i<a.size();i++){
    Anchor L=a.get(i-1), R=a.get(i);
    if (t<=R.t){
      float u = (R.t==L.t)?0:(t-L.t)/(R.t-L.t);
      return lerp(L.s, R.s, u);
    }
  }
  return a.get(a.size()-1).s;
}

boolean hasInteriorAnchor(int k)
{
  if (anchors==null || anchors[k]==null) return false;
  for (Anchor a: anchors[k]) if (a.t>0 && a.t<BEATS) return true;
  return false;
}

// ユーザーのパスマーカー → nodes（パス時刻は等分で割り当て）
void buildNodesFromPassMarkers()
{
  nodes.clear();
  int K = passPlan.size();
  if (K==0) return;

  for (int i=0; i<K; i++) {
    if (i >= passMarkers.size()) break;
    PassMarker pm = passMarkers.get(i);
    if (pm==null || !pm.ready()) continue;

    int passer = pm.passer;
    int recv   = pm.receiver;
    float sP   = pm.sThrow;
    float sR   = pm.sCatch;
    float t_i  = (i+1) * (BEATS / float(K+1));   // キャッチ時刻

    PVector pThrow = posAt(passer, sP);
    PVector pCatch = posAt(recv,   sR);
    float flight   = dist(pThrow.x, pThrow.z, pCatch.x, pCatch.z) / BALL_PX_PER_BEAT;

    PassNode nd = new PassNode(passer, recv, new PVector(pThrow.x,-1.5,pThrow.z), t_i, false);
    nd.sSend = sP;
    nd.sRecv = sR;
    nd.flightBeats = flight;
    nd.tThrow = max(0, t_i - flight);            // ★投げ時刻を保持
    nodes.add(nd);
  }
}

// ダミー含む全員に溜め→直前加速を付与
void addDecoyAnchorsFromNodes()
{
  float eps=0.18f, slowK=0.05f, burstK=0.15f;
  for(int k=0;k<PLAYER_COUNT;k++)
  {
    if (anchors[k]==null) anchors[k] = new ArrayList<Anchor>();
    if (anchors[k].isEmpty())
    {
      anchors[k].add(new Anchor(0,0));
      anchors[k].add(new Anchor(BEATS, totals[k]));
    }
  }
  for (PassNode nd : nodes)
  {
    for (int k=0;k<PLAYER_COUNT;k++)
    {
      if (k==nd.sender || k==nd.receiver) continue;
      if (paths[k].size()<2) continue;
      ArrayList<Anchor> ak = anchors[k];
      float sPrev=0;
      for (int i=0;i<ak.size();i++) if (ak.get(i).t<=nd.t) sPrev=ak.get(i).s;
      float remain = max(0, totals[k]-sPrev);
      float sSlow  = min(totals[k], sPrev + remain*slowK);
      float sBurst = min(totals[k], sSlow + remain*burstK);
      float tSlow  = max(0, nd.t - eps);
      ak.add(new Anchor(tSlow, sSlow));
      ak.add(new Anchor(nd.t,  sBurst));
      Collections.sort(ak, BY_TIME);
    }
  }
  // 端点保証＆単調化
  for (int k=0;k<PLAYER_COUNT;k++)
  {
    ArrayList<Anchor> ak = anchors[k];
    if (ak==null || ak.isEmpty()) continue;
    if (ak.get(0).t>0) ak.add(0,new Anchor(0,0));
    if (ak.get(ak.size()-1).t<BEATS) ak.add(new Anchor(BEATS, totals[k]));
    Collections.sort(ak, BY_TIME);
    ak.get(0).s=0;
    for (int i=1;i<ak.size();i++)
    {
      ak.get(i).s = max(ak.get(i).s, ak.get(i-1).s + 0.1);
      ak.get(i).s = min(ak.get(i).s, totals[k]);
    }
    ak.get(ak.size()-1).s = totals[k];
  }
}


// クリック1回＝現在のパス(step)のパスマーカーを設置
void placePassMarkerWithClick(int mx, int my)
{
  textFont(hudFont);
  if (passMarkerIdx >= passPlan.size()) return;

  int sender   = passPlan.get(passMarkerIdx)[0];
  int receiver = passPlan.get(passMarkerIdx)[1];
  if (paths[sender].size() < 2 || paths[receiver].size() < 2)
  {
    showMsg("両者の走路が必要です");
    return;
  }

  PassMarker pm;
  if (passMarkers.size() <= passMarkerIdx)
  {
    pm = new PassMarker(passMarkerIdx, sender, receiver);
    passMarkers.add(pm);
    waitingThrowClick = true;
    waitingCatchClick = false;
    showMsg("投げ位置をクリック（" + JERSEY[sender] + " の線上）");
  } 
  else
  {
    pm = passMarkers.get(passMarkerIdx);
  }

  PVector click = new PVector(mx, -1.5, my);

  if (waitingThrowClick || (!pm.ready() && pm.sThrow==null))
  {
    float[] d = new float[1];
    float sSend = projectPointToPathS_andDist(sender, click, d);
    if (d[0] > PASS_LINE_HIT_PX) 
    { 
      // ★ライン外クリックを拒否
      showMsg("線上のみ: ±" + int(PASS_LINE_HIT_PX) + "px");
      return;
    }
    pm.sThrow = sSend;
    waitingThrowClick = false;
    waitingCatchClick = true;
    showMsg("受け位置をクリック（" + JERSEY[receiver] + " の線上）");
    return;
  }

  if (waitingCatchClick || (!pm.ready() && pm.sCatch==null))
  {
    float[] d2 = new float[1];
    float sRecv = projectPointToPathS_andDist(receiver, click, d2);
    if (d2[0] > PASS_LINE_HIT_PX)
    {  // ★ライン外クリックを拒否
      showMsg("線上のみ: ±" + int(PASS_LINE_HIT_PX) + "px");
      return;
    }

    PVector throwPos = posAt(sender, pm.sThrow);
    PVector catchPos = posAt(receiver, sRecv);

    // ★Z後方のみ（前方=catch.z > throw.z）
    if (PASS_BACK_ONLY && catchPos.z < throwPos.z - PASS_Z_EPS)
    {
      showMsg("FORWARD禁止: 受けはZ≦投げ");
      return;
    }

    pm.sCatch = sRecv; // 確定
    waitingCatchClick = false;

    buildNodesFromPassMarkers();
    rebuildAnchorsFromNodes();
    addTempoAnchorsForPassersOnly();

    passMarkerIdx++;
    if (passMarkerIdx < passPlan.size())
    {
      waitingThrowClick = true;
      showMsg("次の投げ位置をクリック（" + JERSEY[passPlan.get(passMarkerIdx)[0]] + "）");
    }
    else
    {
      passMarkerEdit = false;
      showMsg("全パス設定OK。SPACEで再生");
    }
  }
}

// パス順（sender→receiverの列）を passQueue から構築
void buildPassPlanFromQueue()
{
  passPlan.clear();
  if (passQueue.isEmpty()) return;
  int cur = chooseInitialOwnerFromQueue();     // 先頭の保持者
  ballOwner = cur;                              // HUDの表示も一致させる
  for (int i=0; i<passQueue.size(); i++)
  {
    int idx = findPlayerByLastDigit(passQueue.get(i));
    if (idx == -1 || idx == cur) continue;     // 無効 or 自分→スキップ
    passPlan.add(new int[]{cur, idx});
    cur = idx;
  }
}

boolean isForwardPass(PVector from, PVector to)
{
  if (!forwardRuleEnabled) return false;  // ← ここで即オフ

  // （元の計算は残しておくと再開が楽）
  PVector v = PVector.sub(to, from);
  v.y = 0;
  PVector d = ATTACK_DIR.copy();
  if (d.magSq() == 0) return false;
  d.normalize();
  return PVector.dot(v, d) > 1e-3;
}


void addTempoAnchorsForPassersOnly()
{
  return;
}

int pickPlayerAt(int mx, int my)
{
  // 1) 先にラベル矩形ヒット
  for (int k = PLAYER_COUNT-1; k >= 0; k--)
  {
    float x = labelSX[k] - labelW[k]/2f;
    float y = labelSY[k] - labelH[k]/2f;
    if (mx >= x && mx <= x + labelW[k] && my >= y && my <= y + labelH[k]) return k;
  }
  // 2) 次に球の円ヒット
  for (int k = PLAYER_COUNT-1; k >= 0; k--)
  {
    float dx = mx - pickSX[k], dy = my - pickSY[k];
    if (dx*dx + dy*dy <= PICK_R*PICK_R) return k;
  }
  return -1;
}

// tPlay を直接変更したとき、パス進行の内部状態を整合させる
void recalcPlaybackStateFromTime(float t) 
{
  // 初期所有者
  int owner = chooseInitialOwnerFromQueue();
  ballInAir = false;
  passTarget = -1;
  plannedCatchPos = null;
  passFlightBeats = 0;
  playbackPassIdx = 0;

  if (nodes == null || nodes.isEmpty()) 
  {
    ballOwner = owner;
    return;
  }

  // ノードを時系列で走査
  for (int i = 0; i < nodes.size(); i++) 
  {
    PassNode nd = nodes.get(i);
    float tThrow = nd.tThrow;
    float tCatch = nd.t;          // 受け時刻
    if (t >= tCatch) 
    {
      // このパスは完了済み
      owner = nd.receiver;
      playbackPassIdx = i + 1;    // 次に消化するノード
      continue;
    }
    if (t >= tThrow && t < tCatch) 
    {
      // いま空中
      ballOwner = nd.sender;
      passTarget = nd.receiver;
      ballInAir = true;
      passStartBeat = tThrow;
      passFlightBeats = max(1e-4, nd.flightBeats);
      passStart = posAt(nd.sender, nd.sSend);
      plannedCatchPos = posAt(nd.receiver, nd.sRecv);
      playbackPassIdx = i + 1;    // すでに開始済みとして進める
      return;
    }
    if (t < tThrow) 
    {
      // 次のパス開始前
      ballOwner = owner;
      playbackPassIdx = i;        // 次はこのパスが開始される
      return;
    }
  }
  // すべてのパスが終わった時間
  ballOwner = owner;
}

// クリック点を選手kの走路に射影。距離sと最近点までの距離[px]を返す
float projectPointToPathS_andDist(int k, PVector pos, float[] outDist)
{
  ArrayList<PVector> path = paths[k];
  if (path.size()<2) { if(outDist!=null) outDist[0]=1e9; return 0; }
  float bestD2=1e12f,bestS=0,acc=0;
  for (int i=1;i<path.size();i++)
  {
    PVector A=path.get(i-1),B=path.get(i);
    float ax=A.x, az=A.z, bx=B.x, bz=B.z;
    float vx=bx-ax, vz=bz-az;
    float segLen2 = vx*vx + vz*vz;
    if (segLen2==0) continue;
    float t = ((pos.x-ax)*vx + (pos.z-az)*vz)/segLen2;
    t = constrain(t,0,1);
    float px=ax+vx*t, pz=az+vz*t;
    float d2 = sq(pos.x-px)+sq(pos.z-pz);
    if (d2<bestD2){ bestD2=d2; bestS=acc+sqrt(segLen2)*t; }
    acc += sqrt(segLen2);
  }
  if (outDist!=null) outDist[0]=sqrt(bestD2);
  return bestS;
}

// 敵の初期配置
void initOpponents() 
{
  if (oppPos == null)  oppPos = new PVector[OPP_COUNT];
  if (markTo == null)  markTo = new int[OPP_COUNT];
  if (backPos == null) backPos = new PVector[BACK_IDX.length];

  // 1:1 マーク（index 対応）
  for (int i = 0; i < OPP_COUNT; i++) markTo[i] = DEFENDER_IDX[i];

  int idx15 = -1;
  for (int i = 0; i < PLAYER_COUNT; i++) if (JERSEY[i] == 15) { idx15 = i; break; }
  if (idx15 == -1) idx15 = findPlayerByLastDigit(5); // 念のためのフォールバック
  markTo[4] = idx15;  // 4th defender → attack #15
  
  // 初期位置：担当アタッカーの X に合わせ、Z は固定
  for (int i = 0; i < OPP_COUNT; i++)
  {
    PVector a = currentDisplayPos(markTo[i]);
    oppPos[i] = new PVector(a.x, -BALL_R, DEF_LINE_Z);
  }
  // 後方（11,15）
  for (int i = 0; i < BACK_IDX.length; i++)
  {
    PVector a = currentDisplayPos(BACK_IDX[i]);
    backPos[i] = new PVector(a.x, -BALL_R, BACKFIELD_Z);
  }
}

int countLeftAttackers()
{
  int c=0; for(int i=0;i<PLAYER_COUNT;i++) if (basePos[i].x < 400) c++; return c;
}
int countRightAttackers()
{
  int c=0; for(int i=0;i<PLAYER_COUNT;i++) if (basePos[i].x > 400) c++; return c;
}

void moveXWithCap(PVector p, float tx, float tz, float maxStep)
{
  float dx = tx - p.x;
  if (abs(dx) > maxStep) dx = (dx>0 ? maxStep : -maxStep);
  p.x += dx; p.z = tz;
}

// ライン外をマークする後方2人が、誰を追うか（攻撃側index）
int backMark11 = -1;
int backMark15 = -1;

void initDefenseForCenter()
{
  // 基準は #9 のX。見つからなければ中央(FB15_CENTER_X)をフォールバック
  int idx9 = findPlayerByLastDigit(9);
  float pivot = (idx9 != -1) ? basePos[idx9].x : FB15_CENTER_X;
  
  for (int i = 0; i < DEF_LINE_COUNT; i++)
  {
    defMark[i] = -1;
    defPos[i]  = null;
    defX[i]    = 0;
  }
  
  // 候補（#15はライン対象外）
  ArrayList<Integer> cand = new ArrayList<Integer>();
  for (int i = 0; i < PLAYER_COUNT; i++) 
  {
    if (paths[i].size() > 0 && isLineEligible(i)) cand.add(i);
  }
  
  // pivot からの距離が近い順に並べ、先頭5人を採用
  Collections.sort(cand, (a, b) -> 
  Float.compare(abs(basePos[a].x - pivot), abs(basePos[b].x - pivot)));
  ArrayList<Integer> picked = new ArrayList<Integer>();
  for (int i = 0; i < cand.size() && picked.size() < DEF_LINE_COUNT; i++)
  {
    picked.add(cand.get(i));
  }
  
  // #9 を必ず含める（含まれていなければ最遠の1人と入れ替え）
  if (idx9 != -1 && !picked.contains(idx9))
  {
    if (picked.size() == 0 && cand.size() > 0) 
    {
      picked.add(cand.get(0));
    }
    int farIdx = 0;
    float farDist = -1;
    for (int i = 0; i < picked.size(); i++) 
    {
      float d = Math.abs(basePos[picked.get(i)].x - pivot);
      if (d > farDist) { farDist = d; farIdx = i; }
    }
    if (idx9 >= 0) picked.set(farIdx, idx9);
  }
  
  // 万一 picked が5未満なら、残りをX昇順で補完
  if (picked.size() < DEF_LINE_COUNT) 
  {
    // X昇順の残り候補
    ArrayList<Integer> rest = new ArrayList<Integer>(cand);
    rest.removeAll(picked);
    Collections.sort(rest, (a, b) -> Float.compare(basePos[a].x, basePos[b].x));
    for (int i = 0; i < rest.size() && picked.size() < DEF_LINE_COUNT; i++) 
    {
      picked.add(rest.get(i));
    }
  }
  
  // X昇順で整列して defMark / defPos を確定
  Collections.sort(picked, (a, b) -> Float.compare(basePos[a].x, basePos[b].x));
  for (int i = 0; i < picked.size() && i < DEF_LINE_COUNT; i++)
  {
    int atk = picked.get(i);
    defMark[i] = atk;
    defX[i]    = basePos[atk].x;
    defPos[i]  = new PVector(defX[i], -1.5, DEF_LINE_Z);
    defZ[i]    = DEF_LINE_Z;   
  }
  
  

  // ---- 後方（11/15）の担当決め ----
  java.util.HashSet<Integer> lineSet = new java.util.HashSet<Integer>();
  for (int i=0;i<DEF_LINE_COUNT;i++) lineSet.add(defMark[i]);

  ArrayList<Integer> rest = new ArrayList<Integer>();
  for (int i=0;i<PLAYER_COUNT;i++) if (!lineSet.contains(i)) rest.add(i);
  
  
  ArrayList<Integer> restNo11 = new ArrayList<Integer>();
  for (int i = 0; i < rest.size(); i++) 
  {
    int idx = rest.get(i);
    if (JERSEY[idx] != 11) restNo11.add(idx);
  }
  
  int cntL=0, cntR=0;
  for (int i=0;i<DEF_LINE_COUNT;i++)
  {
    if (basePos[defMark[i]].x < pivot) cntL++; else cntR++;
  }
  boolean weakRight = (cntR < cntL);

  
  // ---- 後方11：弱い側の一番外（未マーク）を優先（#11 は完全スキップ）
  backMark11 = -1;
  if (weakRight)
  {
    float best = -1e9;
    for (int idx : restNo11)
      if (basePos[idx].x > pivot && basePos[idx].x > best) { best = basePos[idx].x; backMark11 = idx; }
  } else {
    float best = +1e9;
    for (int idx : restNo11)
      if (basePos[idx].x < pivot && basePos[idx].x < best) { best = basePos[idx].x; backMark11 = idx; }
  }
  if (backMark11 == -1 && !restNo11.isEmpty()) {
    int pick = restNo11.get(0);
    for (int idx : restNo11)
      if (abs(basePos[idx].x - pivot) > abs(basePos[pick].x - pivot)) pick = idx;
    backMark11 = pick;
  }

  // 後方11：弱い側の一番外（未マーク）を優先
  backMark11 = -1;
  if (weakRight){
    float best=-1e9; 
    for (int idx:rest) if (basePos[idx].x>pivot && basePos[idx].x>best){best=basePos[idx].x; backMark11=idx;}
  }else{
    float best=+1e9; 
    for (int idx:rest) if (basePos[idx].x<pivot && basePos[idx].x<best){best=basePos[idx].x; backMark11=idx;}
  }
  if (backMark11==-1 && !rest.isEmpty()){
    int pick=rest.get(0);
    for (int idx:rest)
      if (abs(basePos[idx].x-pivot)>abs(basePos[pick].x-pivot)) pick=idx;
    backMark11=pick;
  }

  // 後方15：未マークに攻撃#15がいれば担当、いなければ中央
  backMark15 = -1;
  for (int idx:rest){ if (JERSEY[idx]==15 && idx!=backMark11){ backMark15=idx; break; } }

  float z11 = DEF_LINE_Z - BACK11_Z_OFFSET;
  float z15 = DEF_LINE_Z - BACK15_Z_OFFSET;
  defBack11.set(backMark11>=0 ? basePos[backMark11].x : (weakRight? pivot+110 : pivot-110), -1.5, z11);
  defBack15.set(FB15_CENTER_X, -1.5, z15);
  back11ZOffset = 0;   // ← 追加
  back15ZOffset = 0;   // ← 追加
}

// 人数の少ないサイド内で「一番右（x最大）のラインDF」の x を返す
// ラインDF4人(defMark/defPos)の中から、人数が少ないサイドの「一番右（外側）」の x を返す
float back11TargetXForWeakerSide()
{
  // ラインDFの左右人数で少ない側を判定
  int cntL = 0, cntR = 0;
  for (int i=0; i<DEF_LINE_COUNT; i++)
  {
    if (basePos[defMark[i]].x < 400) cntL++; else cntR++;
  }
  boolean weakRight = (cntR < cntL);

  float bestX = weakRight ? -1e9 : +1e9;
  boolean found = false;

  for (int i=0; i<DEF_LINE_COUNT; i++) {
    boolean isRight = (basePos[defMark[i]].x > 400);
    if (isRight != weakRight) continue;

    float x = defPos[i].x; // 現在のラインDF位置でOK
    if (weakRight) 
    { // 右が少ない → そのサイドで x 最大を取る
      if (!found || x > bestX) { bestX = x; found = true; }
    }
    else 
    {         // 左が少ない → そのサイドで x 最小を取る
      if (!found || x < bestX) { bestX = x; found = true; }
    }
  }

  // フォールバック（万一見つからないとき）
  if (!found) return 400 + (weakRight ? +110 : -110);
  return bestX;
}


// openDir: +1 = +X 側がオープン（左スクラム） / -1 = -X 側がオープン（右スクラム）
void initDefenseForScrum(int openDir)
{
  final float pivot = (openDir > 0) ? 200f : 600f; // 左=200 / 右=600

  ArrayList<Integer> cand = new ArrayList<Integer>();
  for (int i=0;i<PLAYER_COUNT;i++) if (paths[i].size()>0 && isLineEligible(i)) cand.add(i);

  ArrayList<Integer> L = new ArrayList<Integer>(), R = new ArrayList<Integer>();
  for (int idx:cand){ if (basePos[idx].x < pivot) L.add(idx); else R.add(idx); }

  Collections.sort(R, (a,b)-> Float.compare(basePos[a].x - pivot, basePos[b].x - pivot));
  Collections.sort(L, (a,b)-> Float.compare(pivot - basePos[a].x, pivot - basePos[b].x));

  ArrayList<Integer> line = new ArrayList<Integer>(DEF_LINE_COUNT);
  // 左スクラム（openDir>0）は L→R、右スクラム（openDir<0）は R→L の順で詰める
  if (openDir > 0) 
  {
    for (int idx : L) { if (line.size() < DEF_LINE_COUNT) line.add(idx); }
    for (int idx : R) { if (line.size() < DEF_LINE_COUNT) line.add(idx); }
  } 
  else 
  {
    for (int idx : R) { if (line.size() < DEF_LINE_COUNT) line.add(idx); }
    for (int idx : L) { if (line.size() < DEF_LINE_COUNT) line.add(idx); }
  }


  Collections.sort(line, (a,b)-> Float.compare(basePos[a].x, basePos[b].x));
  for (int i=0;i<DEF_LINE_COUNT;i++)
  {
    int atk=line.get(i);
    defMark[i]=atk;
    defX[i]=basePos[atk].x;
    defPos[i]=new PVector(defX[i], -1.5, DEF_LINE_Z);
    defZ[i]    = DEF_LINE_Z;
  }

  java.util.HashSet<Integer> lineSet = new java.util.HashSet<Integer>(line);
  ArrayList<Integer> rest = new ArrayList<Integer>();
  for (int i=0;i<PLAYER_COUNT;i++) if (!lineSet.contains(i)) rest.add(i);
  
  ArrayList<Integer> restNo11 = new ArrayList<Integer>();
  for (int i = 0; i < rest.size(); i++) 
  {
    int idx = rest.get(i);
    if (JERSEY[idx] != 11) restNo11.add(idx);
  }

  int cntL=0,cntR=0; for (int idx:line){ if (basePos[idx].x<pivot) cntL++; else cntR++; }
  boolean weakRight = (cntR < cntL);

  // backMark11 の選定ブロックを rest → restNo11 に置換
  backMark11 = -1;
  if (weakRight) 
  {
    float best = -1e9;
    for (int idx : restNo11)
      if (basePos[idx].x > pivot && basePos[idx].x > best) { best = basePos[idx].x; backMark11 = idx; }
  } 
  else 
  {
    float best = +1e9;
    for (int idx : restNo11)
      if (basePos[idx].x < pivot && basePos[idx].x < best) { best = basePos[idx].x; backMark11 = idx; }
  }
  if (backMark11 == -1 && !restNo11.isEmpty())
  {
    int pick = restNo11.get(0);
    for (int idx : restNo11)
      if (abs(basePos[idx].x - pivot) > abs(basePos[pick].x - pivot)) pick = idx;
    backMark11 = pick;
  }

  backMark15 = -1;
  for (int idx:rest){ if (JERSEY[idx]==15 && idx!=backMark11){ backMark15=idx; break; } }

  float z11 = DEF_LINE_Z - BACK11_Z_OFFSET;
  float z15 = DEF_LINE_Z - BACK15_Z_OFFSET;

  defBack11.set(
    backMark11>=0 ? basePos[backMark11].x : (weakRight? pivot+110 : pivot-110),
    -1.5, z11
  );

  // ★ FB15の初期位置は中央に固定（以後の追尾は updateDefense() 側で従来どおり）
  defBack15.set(FB15_CENTER_X, -1.5, z15);
  back11ZOffset = 0;   // ← 追加
  back15ZOffset = 0;   // ← 追加

}

void updateDefense(float dtBeats)
{
  if (defPos[0]==null) return;

  // ★ スクラブ（大きく時間が飛んだ）かどうかを判定
  boolean snapToTime = userScrubbing || abs(tPlay - prevTPlay) >= DEF_SPEED_SCRUB_SNAP_BEATS;

  // 1) ラインDFの目標X（担当アタッカーの現在X）を取得
  float[] target = new float[DEF_LINE_COUNT];
  for (int i=0; i<DEF_LINE_COUNT; i++) {
    target[i] = currentDisplayPos(defMark[i]).x;
  }
  // 左→右で間隔を確保
  Arrays.sort(target);
  for (int i=1; i<DEF_LINE_COUNT; i++) {
    if (target[i] - target[i-1] < DEF_SEP_X) target[i] = target[i-1] + DEF_SEP_X;
  }

  // 2) スナップ or 速度制限追従
  float step = DEF_SPEED * dtBeats;
  for (int i = 0; i < DEF_LINE_COUNT; i++) {
    if (snapToTime) {
      // ★時間ジャンプ時は一発で合わせる
      defX[i] = target[i];
    } else {
      float dx = target[i] - defX[i];
      if (abs(dx) > step) dx = (dx>0 ? step : -step);
      defX[i] += dx;
    }
    defPos[i].x = defX[i];
  
    // ====== ここから Z の微追従   ======
    // 基準は defZ[i]（フォーメーション/shiftClosestDefenseZ の結果）
    float baseZ  = defZ[i];
    float markZ  = currentDisplayPos(defMark[i]).z;
  
    // マーク相手のZ変化の一部だけ追う
    float drift  = (markZ - baseZ) * DEF_Z_FOLLOW;
    drift        = constrain(drift, -DEF_Z_DRIFT_MAX, DEF_Z_DRIFT_MAX);
  
    // ラインを越えすぎない（−Z方向＝前進は安全マージンまで）
    float zTarget = baseZ + drift;
    zTarget       = max(zTarget, baseZ - DEF_LINE_SAFE_MARGIN);
  
    if (snapToTime) {
      defPos[i].z = zTarget;  // スクラブ時はスナップ
    } else {
      float stepZ = DEF_Z_SPEED * dtBeats;
      float dz    = zTarget - defPos[i].z;
      if (abs(dz) > stepZ) dz = (dz>0 ? stepZ : -stepZ);
      defPos[i].z += dz;
    }
    // ====== 微追従ここまで ======
  }

  // 3) 後方11（Z固定）
  if (SHOW_DEF_BACK11) {
    float tz11 = DEF_LINE_Z - BACK11_Z_OFFSET + back11ZOffset; // Zは固定
    float tx11 = (backMark11>=0)
      ? currentDisplayPos(backMark11).x
      : (countRightAttackers()<countLeftAttackers()? 400+110 : 400-110);

    if (snapToTime) {
      defBack11.x = tx11;        // ★スナップ
      defBack11.z = tz11;
    } else {
      moveXWithCap(defBack11, tx11, tz11, BACK_SPEED * dtBeats);
    }
  }

  // 4) 後方15（Z固定）
  if (SHOW_DEF_BACK15) {
    float tz15 = DEF_LINE_Z - BACK15_Z_OFFSET + back15ZOffset; // Zは固定

    float bx = currentBallXForDefense();
    float tx = (abs(bx - FB15_CENTER_X) < FB15_DEADBAND) ? FB15_CENTER_X : bx;
    tx = lerp(FB15_CENTER_X, tx, 1.0 - FB15_CENTRAL_BIAS);
    tx += FB15_LEAD_X * ATTACK_DIR.x;
    tx = constrain(tx, FB15_MIN_X, FB15_MAX_X);

    if (snapToTime) {
      defBack15.x = tx;          // ★スナップ
      defBack15.z = tz15;
    } else {
      moveXWithCap(defBack15, tx, tz15, BACK_SPEED * FB15_SPEED_SCALE * dtBeats);
    }
  }

  // ★ 最後に現在の時刻を記録（次フレームの差分判定に使う）
  prevTPlay = tPlay;
}

void drawDefense()
{
  pushStyle();
  noStroke();

  // ライン4人（赤）
  fill(ENEMY_RED);
  for(int i=0;i<DEF_LINE_COUNT;i++)
  {
    if (defPos[i]==null) continue;
    pushMatrix(); translate(defPos[i].x, playerHoverY, defPos[i].z); sphere(BALL_R); popMatrix();
  }

  // 後方11（オレンジ）／15（ピンク）
  if (SHOW_DEF_BACK11)
  {
    fill(ENEMY_RED);
    pushMatrix(); translate(defBack11.x, playerHoverY, defBack11.z); sphere(BALL_R); popMatrix();
  }
  if (SHOW_DEF_BACK15)
  {
    fill(ENEMY_RED);
    pushMatrix(); translate(defBack15.x, playerHoverY, defBack15.z); sphere(BALL_R); popMatrix();
  }

  popStyle();
}

float currentBallXForDefense() {
  if (ballInAir) {
    if (plannedCatchPos != null && passFlightBeats > 0) {
      float u = constrain((tPlay - passStartBeat) / passFlightBeats, 0, 1);
      return lerp(passStart.x, plannedCatchPos.x, u);
    } else if (passTarget >= 0) { // フォールバック（手動Tパス時など）
      PVector recvPos = currentDisplayPos(passTarget);
      return lerp(passStart.x, recvPos.x, passT);
    } else {
      return (passStart != null) ? passStart.x : currentDisplayPos(ballOwner).x;
    }
  } else {
    // 保持者の頭上＝ボール
    return currentDisplayPos(ballOwner).x;
  }
}

void drawScrumMarker() {
  // 3D: 地面に楕円
  pushStyle();
  pushMatrix();
  translate(SCRUM_X, -1.5, SCRUM_Z);  // 地面すれすれ
  rotateX(HALF_PI);                   // XZ 平面に寝かせる
  noStroke();
  fill(255, 255, 255, 70);            // うっすら白
  ellipse(0, 0, SCRUM_RX*2, SCRUM_RZ*2);
  noFill();
  stroke(255, 230);
  strokeWeight(2);
  ellipse(0, 0, SCRUM_RX*2, SCRUM_RZ*2);
  popMatrix();
  popStyle();

  textFont(hudFont, 12);

  // HUD: 「スクラム」のラベル（ライト無視）
  float sx = screenX(SCRUM_X, -1.5, SCRUM_Z);
  float sy = screenY(SCRUM_X, -1.5, SCRUM_Z) - 18;

  hint(DISABLE_DEPTH_TEST);
  pushStyle(); pushMatrix();
  resetMatrix(); camera(); noLights();
  textSize(12); textAlign(CENTER, CENTER);
  String t = "SCRUM";
  float w = max(40, textWidth(t));
  rectMode(CENTER);
  noStroke(); fill(0, 150);
  rect(sx, sy+15, w, 16, 6);
  fill(255);
  text(t, sx, sy+15);
  popMatrix(); popStyle();
  hint(ENABLE_DEPTH_TEST);
}

// スクラムに最も近いディフェンス1人のZを +dz
void shiftClosestDefenseZ(float dz)
{
  float best = 1e12;
  int bestType = -1; // 0=ラインDF(defPos/defZ), 1=後方11, 2=後方15
  int bestIdx  = -1;

  // ラインDF（5人）
  for (int i = 0; i < DEF_LINE_COUNT; i++) {
    if (defPos[i] == null) continue;
    float d2 = sq(defPos[i].x - SCRUM_X) + sq(defPos[i].z - SCRUM_Z);
    if (d2 < best) { best = d2; bestType = 0; bestIdx = i; }
  }
  // 後方11
  if (SHOW_DEF_BACK11 && defBack11 != null) {
    float d2 = sq(defBack11.x - SCRUM_X) + sq(defBack11.z - SCRUM_Z);
    if (d2 < best) { best = d2; bestType = 1; }
  }
  // 後方15
  if (SHOW_DEF_BACK15 && defBack15 != null) {
    float d2 = sq(defBack15.x - SCRUM_X) + sq(defBack15.z - SCRUM_Z);
    if (d2 < best) { best = d2; bestType = 2; }
  }

  // 実際に +dz（※Zは updateDefense で上書きされるので基準値/オフセットを変える）
  if (bestType == 0 && bestIdx >= 0) {
    defZ[bestIdx] += dz;             // ← ラインDFは defZ を更新
  } else if (bestType == 1) {
    back11ZOffset += dz;             // ← 後方11はオフセットを更新
  } else if (bestType == 2) {
    back15ZOffset += dz;             // ← 後方15も同様
  }
  
  // 関数末尾に追加（ラインDF用）
  for (int i=0; i<DEF_LINE_COUNT; i++) {
    if (defPos[i] != null) defPos[i].z = defZ[i];
  }
  // 後方DFも即反映
  defBack11.z = DEF_LINE_Z - BACK11_Z_OFFSET + back11ZOffset;
  defBack15.z = DEF_LINE_Z - BACK15_Z_OFFSET + back15ZOffset;

}

// 再生開始用：現在のフォーメーションに合わせてDFを初期化
void resetDefenseForReplay()
{
  if (formation == 0)      initDefenseForScrum(+1); // Left
  else if (formation == 1) initDefenseForScrum(-1); // Right
  else                     initDefenseForCenter();  // Center

  // applyFormation() と同じ見た目に揃える（必要なければ削ってOK）
  shiftClosestDefenseZ(+20);
}

float currentBallZForDefense() {
  if (ballInAir) {
    if (plannedCatchPos != null && passFlightBeats > 0) {
      float u = constrain((tPlay - passStartBeat) / passFlightBeats, 0, 1);
      return lerp(passStart.z, plannedCatchPos.z, u);
    } else if (passTarget >= 0) {
      PVector recvPos = currentDisplayPos(passTarget);
      return lerp(passStart.z, recvPos.z, passT);
    } else {
      return (passStart != null) ? passStart.z : currentDisplayPos(ballOwner).z;
    }
  } else {
    return currentDisplayPos(ballOwner).z;
  }
}


// ヘルプ
void hintText() 
{
  hint(DISABLE_DEPTH_TEST);
  pushStyle();
  pushMatrix();
  resetMatrix();
  camera();
  noLights();
  rectMode(CORNER);
  
  textFont(hudFont);

  // —— 小さめレイアウト定数 —— //
  final int PAD   = 8;   // 余白（← これが α）
  final int GAP_S = 4;
  final int GAP_M = 6;

  final int H_TOP   = 18;
  final int H_CTRL  = 16;
  final int H_QUEUE = 16;
  final int H_TL    = 8;

  final int FS_TOP   = 10;
  final int FS_BODY  = 9;
  final int FS_TOAST = 10;
  
  final int margin = 10;

  int x = 10, y = 10;
  int wFull = width - 20;          // タイムラインだけは従来のフル幅のまま

  // ===== 1) ステータス帯 =====
  String modeChip = drawMode ? "DRAW" : "VIEW";
  String leftInfo = drawMode
    ? "  ドラッグ=走路   /   Shift+ドラッグ=初期位置   /   プレイヤークリック=選択  "
    : "  右ドラッグ=回転   /   ←→↑↓=角度   /   [ ]=ズーム  ";

  String nextStr = "-";
  if (passIdx < passQueue.size()) {
    int d = passQueue.get(passIdx);
    int jersey = -1;
    for (int i=0;i<PLAYER_COUNT;i++) { if (JERSEY[i] % 10 == d) { jersey = JERSEY[i]; break; } }
    nextStr = (jersey==-1) ? (""+d) : (""+jersey);
  }
  String rightInfo = "Sel:"+JERSEY[currentPlayer] + "   "
                   + "Ball:"+JERSEY[ballOwner]    + "   "
                   + "Next:"+nextStr              + "   "
                   + "Form:"+FORM_NAME[formation];

  textSize(FS_TOP);
  float chipW = textWidth(modeChip) + 14;
  float leftBarW = PAD + chipW + 6 + textWidth(leftInfo) + PAD; // ← 背景幅を文字＋αに
  noStroke(); fill(0,170);
  rect(x, y, leftBarW, H_TOP, 7);

  fill(drawMode ? color(60,180,90,230) : color(60,140,220,230));
  rect(x+PAD-6, y+3, chipW, H_TOP-6, 9);
  fill(255); textAlign(LEFT, CENTER);
  text(modeChip, x+PAD, y + H_TOP/2f);

  fill(255); textAlign(LEFT, CENTER);
  text(leftInfo, x + PAD + chipW + 6, y + H_TOP/2f);

  float rW = textWidth(rightInfo) + PAD*1.5f;     // ← 右側は元から可変幅なのでそのまま
  fill(0,145);
  rect(width - margin - rW, y, rW, H_TOP, 7);
  fill(255); textAlign(RIGHT, CENTER);
  text(rightInfo, width - margin - PAD*0.75f, y + H_TOP/2f);

  // ===== 2) 操作ガイド帯 =====
  y += H_TOP + GAP_S;
  String controls = "SPACE=再生/一時停止   T=次に投げる(キュー)   TAB=描画↔鑑賞   P=PASS-MARKER編集   R=全リセット";
  textSize(FS_BODY);
  float ctrlW = textWidth(controls) + PAD*2;      // ← 可変幅
  fill(0,155); rect(x, y, ctrlW, H_CTRL, 7);
  fill(255); textAlign(LEFT, CENTER);
  text(controls, x+PAD, y+H_CTRL/2f);

  // ===== 3) パスキュー帯（REC付き） =====
  y += H_CTRL + GAP_S;
  String q = (passEditMode ? "[REC:編集中]  " : (!passQueue.isEmpty() ? "[REC:ON]  " : "[REC:OFF]  ")) + "Queue: ";
  for (int i=0;i<passQueue.size();i++){
    String piece = str(passQueue.get(i));
    if (i==passIdx) piece = ">" + piece + "<";
    q += piece;
    if (i < passQueue.size()-1) q += " → ";
  }
  textSize(FS_BODY);
  float qW = textWidth(q) + PAD*2;
  float boxW = qW;                                   // ← 上限を撤廃して文字＋αに
  fill(0,155); rect(x, y, boxW, H_QUEUE, 7);
  fill(255); textAlign(LEFT, CENTER);
  text(q, x+PAD, y+H_QUEUE/2f);

  // RECボタン
  recX = (int)(x + boxW + 6);
  recY = y; recW = 44; recH = H_QUEUE;
  noStroke(); fill(passEditMode ? color(220,60,60,210) : color(90,90,90,210));
  rect(recX, recY, recW, recH, 7);
  fill(255); textAlign(CENTER, CENTER);
  text("REC", recX + recW/2f, recY + recH/2f);

  // 再生情報（右寄せ・可変幅のまま）
  String playInfo = nf(tPlay,1,2) + " / " + BEATS + " beats    speed:" + nf(tSpeed,1,2);
  float pW = textWidth(playInfo) + PAD*2;
  fill(0,140); rect(width - margin - pW, y, pW, H_QUEUE, 7);
  fill(255); textAlign(RIGHT, CENTER);
  text(playInfo, width - margin - PAD, y + H_QUEUE/2f);

  // ===== 4) タイムライン（これはフル幅のまま） =====
  y += H_QUEUE + GAP_M;
  tlX = x; tlY = y; tlW = wFull; tlH = H_TL;
  noStroke(); fill(0,110); rect(tlX, tlY, tlW, tlH, 5);
  float prog = constrain(tPlay / (float)BEATS, 0, 1);
  fill(255,200,0); rect(tlX, tlY, tlW*prog, tlH, 5);

  stroke(255,210); strokeWeight(1.25);
  for (int b=0;b<=BEATS;b++){
    float tx = tlX + tlW * (b / (float)BEATS);
    line(tx, tlY-4, tx, tlY+tlH+4);
  }
  noStroke();
  if (nodes != null && !nodes.isEmpty()){
    for (int i=0;i<nodes.size();i++){
      PassNode nd = nodes.get(i);
      float tx = tlX + tlW * (nd.tThrow / (float)BEATS);
      float y0 = tlY - 10, y1 = tlY - 2;
      fill(255,210,0); triangle(tx, y0,  tx-4.5f, y1,  tx+4.5f, y1);
    }
  }

  // ===== 5) パスマーカー編集ガイド（ON時のみ） =====
  if (passMarkerEdit){
    String info = "PASS-MARKER: [線上±" + int(PASS_LINE_HIT_PX) + "px" + (PASS_BACK_ONLY ? " / 前方禁止" : "") + "]  "
      + (passMarkerIdx < passPlan.size()
         ? ("投げ位置→受け位置をクリック (" + (passMarkerIdx+1) + "/" + passPlan.size() + ")")
         : "全パス設定OK：SPACEで再生");
    textSize(FS_BODY);
    float infoW = textWidth(info) + PAD*2;          // ← 可変幅
    y += tlH + GAP_S;
    fill(0,155); rect(x, y, infoW, 18, 7);
    fill(255); textAlign(LEFT, CENTER);
    text(info, x+PAD, y+9);

    String pm = "Markers " + passMarkers.size() + " / " + passPlan.size();
    float pmW = textWidth(pm) + PAD*2;
    fill(0,140); rect(width - margin - pmW, y, pmW, 18, 7);
    fill(255); textAlign(RIGHT, CENTER);
    text(pm, width - margin - PAD, y + 9);
  }

  // ===== 6) トースト =====（そのまま）
  if (hudMsgTimer > 0)
  {
    String m = hudMsg;
    textSize(FS_TOAST);
    float pad2 = 12;
    float wm = textWidth(m) + pad2*2;
    float xm = width/2f - wm/2f;
    float ym = tlY + tlH + 30;
    noStroke(); fill(0,175); rect(xm, ym, wm, 22, 7);
    fill(255); textAlign(CENTER, CENTER);
    text(m, xm + wm/2f, ym + 11);
    hudMsgTimer--;
  }

  popMatrix();
  popStyle();
  hint(ENABLE_DEPTH_TEST);
}
