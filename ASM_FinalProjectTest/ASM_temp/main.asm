TITLE Tetris Dual Player
INCLUDE Irvine32.inc

; ==============================================================================
; [前置設定] Windows API 圖形編碼
; ==============================================================================
; 宣告切換編碼的 API，用來強迫 Console 使用 437 圖形編碼，避免擴充 ASCII 變成中文亂碼(api)
SetConsoleOutputCP PROTO, wCodePageID:DWORD 

; ==============================================================================
; [常數定義] 遊戲基礎設定
; ==============================================================================
BOARD_W = 10         ; 盤面寬度 (10格)
BOARD_H = 20         ; 盤面高度 (20格)
START_X_P1 = 5       ; P1 盤面在螢幕上的 X 座標
START_X_P2 = 35      ; P2 盤面在螢幕上的 X 座標
START_Y = 2          ; 雙方盤面的 Y 座標
BLOCK_CHAR = 0DBh    ; 實心方塊字元 █

.data
; ==============================================================================
; [資料區段] 共用資源與字串
; ==============================================================================
; 預先定義 7 種方塊形狀 (4x4 陣列)
Shape_I BYTE 0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0
Shape_J BYTE 1,1,1,0, 1,0,0,0, 0,0,0,0, 0,0,0,0
Shape_L BYTE 1,1,1,0, 0,0,1,0, 0,0,0,0, 0,0,0,0
Shape_O BYTE 0,0,0,0, 0,1,1,0, 0,1,1,0, 0,0,0,0
Shape_S BYTE 0,1,1,0, 1,1,0,0, 0,0,0,0, 0,0,0,0
Shape_T BYTE 0,0,0,0, 1,1,1,0, 0,1,0,0, 0,0,0,0
Shape_Z BYTE 1,1,0,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
cursorInfo DWORD 10, 0

; --- 計時器變數 ---
TIME_LIMIT = 60000          ; 遊戲時間限制 60 秒 (60000 毫秒)
startTime DWORD 0           ; 紀錄遊戲開始時間
lastSeconds DWORD 99        ; 紀錄上一秒數 (避免重複繪圖導致頻閃)
strTime BYTE "TIME: ", 0    ; 計時器字串
strSec BYTE "s  ", 0        ; 秒數字串 (後面加空白是為了清除十位數變個位數時的殘影)

; 介面文字 
strScore   BYTE "SCORE: ", 0
strP1Win   BYTE ">>> PLAYER 1 WINS! <<<", 0
strP2Win   BYTE ">>> PLAYER 2 WINS! <<<", 0
strTie     BYTE ">>> IT'S A TIE! <<<", 0  
strExitMsg BYTE "Press any key to exit...", 0

; ==============================================================================
; [資料區段] Player 1 專屬狀態變數
; ==============================================================================
Board_P1       BYTE 200 DUP(0)  ; P1 盤面陣列 (10x20)
curShape_P1    BYTE 16 DUP(0)   ; P1 當前掉落的方塊
tempShape_P1   BYTE 16 DUP(0)   ; P1 旋轉測試用的暫存區
backupShape_P1 BYTE 16 DUP(0)   ; P1 旋轉防撞的備份區
curX_P1        DWORD 3          ; P1 當前方塊 X 座標
curY_P1        DWORD 0          ; P1 當前方塊 Y 座標
tickCount_P1   DWORD 0          ; P1 下落計時器
score_P1       DWORD 0          ; P1 分數
isDead_P1      BYTE 0           ; P1 存活狀態 (0=活著, 1=死亡)

; ==============================================================================
; [資料區段] Player 2 專屬狀態變數
; ==============================================================================
Board_P2       BYTE 200 DUP(0)  ; P2 盤面陣列 (10x20)
curShape_P2    BYTE 16 DUP(0)   ; P2 當前掉落的方塊
tempShape_P2   BYTE 16 DUP(0)   ; P2 旋轉測試用的暫存區
backupShape_P2 BYTE 16 DUP(0)   ; P2 旋轉防撞的備份區
curX_P2        DWORD 3          ; P2 當前方塊 X 座標
curY_P2        DWORD 0          ; P2 當前方塊 Y 座標
tickCount_P2   DWORD 0          ; P2 下落計時器
score_P2       DWORD 0          ; P2 分數
isDead_P2      BYTE 0           ; P2 存活狀態 (0=活著, 1=死亡)


.code
; ==============================================================================
; [主程式] 遊戲進入點與主迴圈
; ==============================================================================
main PROC
    ; --- 系統初始化 ---
    INVOKE SetConsoleOutputCP, 437  ; 強制使用圖形編碼
    call Randomize                  ; 亂數種子初始化
    call Clrscr                     ; 清空螢幕
    call HideCursor                 ; 隱藏游標避免閃爍
    
    ; --- 畫面初始化 ---
    call DrawBoardBorder_P1         ; 畫 P1 邊框
    call DrawBoardBorder_P2         ; 畫 P2 邊框
    call DrawScore_P1               ; 畫 P1 初始分數
    call DrawScore_P2               ; 畫 P2 初始分數

    ; --- 遊戲資料初始化 ---
    call SpawnPiece_P1              ; 產生 P1 第一個方塊
    call SpawnPiece_P2              ; 產生 P2 第一個方塊
    call DrawBoard_P1               ; 渲染 P1 空盤面
    call DrawBoard_P2               ; 渲染 P2 空盤面

    ; --- 計時器初始化 ---
    call GetMseconds
    mov startTime, eax
    call DrawTimerInit              ; 畫出 TIME: 標籤


GameLoop:

    ; 計時器邏輯
    call GetMseconds                ; 抓取時間 (api)
    sub eax, startTime              ; 計算經過的時間 (毫秒)
    cmp eax, TIME_LIMIT
    jge GameOverCalc                ; 若時間到，跳到比分數結算

    mov ebx, TIME_LIMIT
    sub ebx, eax                    ; 算出剩下的時間 (毫秒)
    mov eax, ebx
    xor edx, edx
    mov ecx, 1000
    div ecx                         ; 除以 1000 轉換為「秒」 (結果存在 eax)

    ; 只有當秒數變動時，才重畫數字 (防止頻閃)
    .IF eax != lastSeconds
        mov lastSeconds, eax
        call DrawTimerValue
    .ENDIF

    ; --- 1. 畫面更新層 ---
    .IF isDead_P1 == 0
        call DrawCurrentPiece_P1    ; P1 活著才畫方塊
    .ENDIF
    
    .IF isDead_P2 == 0
        call DrawCurrentPiece_P2    ; P2 活著才畫方塊
    .ENDIF
    
    ; --- 2. 系統節奏控制 ---
    mov eax, 50                     ; 迴圈延遲 50ms
    call Delay ; Sleep (api)
    
    ; --- 3. 玩家輸入讀取 ---
    call ReadKey                    ; 按鍵輸入讀取(api)
    jz CheckGravity_P1              ; 如果沒按鍵，直接去算重力

    ; P1 操作判斷 (WASD)
    .IF isDead_P1 == 0
        .IF al == 'a' || al == 'A'
            call EraseCurrentPiece_P1
            dec curX_P1
            call CheckCollision_P1
            .IF eax == 1
                inc curX_P1
            .ENDIF
        .ELSEIF al == 'd' || al == 'D'
            call EraseCurrentPiece_P1
            inc curX_P1
            call CheckCollision_P1
            .IF eax == 1
                dec curX_P1
            .ENDIF
        .ELSEIF al == 's' || al == 'S'
            call UpdateBlockDown_P1
            mov tickCount_P1, 0
        .ELSEIF al == 'w' || al == 'W'
            call EraseCurrentPiece_P1
            call RotatePiece_P1
        .ENDIF
    .ENDIF

    ; P2 操作判斷 (方向鍵)
    .IF isDead_P2 == 0
        .IF al == 0 && ah == 4Bh        ; Left Arrow
            call EraseCurrentPiece_P2
            dec curX_P2
            call CheckCollision_P2
            .IF eax == 1
                inc curX_P2
            .ENDIF
        .ELSEIF al == 0 && ah == 4Dh    ; Right Arrow
            call EraseCurrentPiece_P2
            inc curX_P2
            call CheckCollision_P2
            .IF eax == 1
                dec curX_P2
            .ENDIF
        .ELSEIF al == 0 && ah == 50h    ; Down Arrow
            call UpdateBlockDown_P2
            mov tickCount_P2, 0
        .ELSEIF al == 0 && ah == 48h    ; Up Arrow
            call EraseCurrentPiece_P2
            call RotatePiece_P2
        .ENDIF
    .ENDIF

    ; 共通操作
    .IF al == 'q' || al == 'Q'          ; 按 Q 強制退出
        jmp GameOver
    .ENDIF

    ; --- 4. 自動下落邏輯 (重力) ---
CheckGravity_P1:
    cmp isDead_P1, 1
    je CheckGravity_P2                  ; 如果 P1 死了，跳過下落邏輯
    
    inc tickCount_P1
    cmp tickCount_P1, 10                ; 10 tick * 50ms = 500ms 掉一格
    jl CheckGravity_P2
    mov tickCount_P1, 0
    call UpdateBlockDown_P1             ; 觸發 P1 下落

CheckGravity_P2:
    cmp isDead_P2, 1
    je LoopEnd                          ; 如果 P2 死了，跳過下落邏輯

    inc tickCount_P2
    cmp tickCount_P2, 10
    jl LoopEnd
    mov tickCount_P2, 0
    call UpdateBlockDown_P2             ; 觸發 P2 下落

LoopEnd:
    jmp GameLoop                        ; 返回主迴圈

; ==============================================================================
; [結算畫面] 勝負判定與離開遊戲
; ==============================================================================
GameOverCalc::                          ; 雙方皆陣亡時會跳到這裡比對分數
    mov eax, score_P1
    cmp eax, score_P2
    jg P1_Wins                          ; P1 分數高
    jl P2_Wins                          ; P2 分數高
    
    ; 平手結算
    mov eax, white
    call SetTextColor
    mov dl, 31
    mov dh, 10
    call Gotoxy ; Gotoxy 定位座標，才能依這個座標做(局部更新) (api)
    mov edx, OFFSET strTie
    call WriteString
    jmp EndWait

P1_Wins::                               ; P1 勝利畫面
    mov eax, lightCyan
    call SetTextColor
    mov dl, 31
    mov dh, 10
    call Gotoxy
    mov edx, OFFSET strP1Win
    call WriteString
    jmp EndWait

P2_Wins::                               ; P2 勝利畫面
    mov eax, Yellow
    call SetTextColor                   ; 設定文字顏色(api)
    mov dl, 31
    mov dh, 10
    call Gotoxy
    mov edx, OFFSET strP2Win
    call WriteString
    jmp EndWait

GameOver::                              ; 手動結束
    jmp EndWait

EndWait::                               ; 等待離開提示
    mov eax, white
    call SetTextColor
    mov dl, 30
    mov dh, 12
    call Gotoxy
    mov edx, OFFSET strExitMsg
    call WriteString

FlushBuffer:                            ; 清空殘留的按鍵緩衝區
    call ReadKey
    jnz FlushBuffer

    call ReadChar                       ; 等待任意鍵關閉
    call Clrscr
    exit
main ENDP



; ==============================================================================
;                              PLAYER 1 專屬副程式
; ==============================================================================

; --- [P1 邏輯] 隨機產生方塊 ---
SpawnPiece_P1 PROC
    pushad
    mov curX_P1, 3
    mov curY_P1, 0
    mov eax, 7                  ; ==== 修改：產生 0~6 的亂數 (共7種) ====
    call RandomRange

    ; 依序判定亂數 eax，跳到對應的複製區
    cmp eax, 0
    je Copy_I_P1
    cmp eax, 1
    je Copy_J_P1
    cmp eax, 2
    je Copy_L_P1
    cmp eax, 3
    je Copy_O_P1
    cmp eax, 4
    je Copy_S_P1
    cmp eax, 5
    je Copy_T_P1
    cmp eax, 6
    je Copy_Z_P1
    jmp Copied_P1               ; 安全跳出 (不應該發生)

Copy_I_P1:
    mov esi, OFFSET Shape_I
    jmp Copied_P1
Copy_J_P1:
    mov esi, OFFSET Shape_J
    jmp Copied_P1
Copy_L_P1:
    mov esi, OFFSET Shape_L
    jmp Copied_P1
Copy_O_P1:
    mov esi, OFFSET Shape_O
    jmp Copied_P1
Copy_S_P1:
    mov esi, OFFSET Shape_S
    jmp Copied_P1
Copy_T_P1:
    mov esi, OFFSET Shape_T
    jmp Copied_P1
Copy_Z_P1:
    mov esi, OFFSET Shape_Z
    jmp Copied_P1

Copied_P1:
    ; 將 esi 複製 16 Bytes 到 edi
    mov edi, OFFSET curShape_P1
    mov ecx, 16
    cld
    rep movsb
    popad
    ret
SpawnPiece_P1 ENDP

; --- [P1 邏輯] 旋轉方塊與防撞 ---
RotatePiece_P1 PROC
    pushad
    ; 1. 備份
    mov esi, OFFSET curShape_P1
    mov edi, OFFSET backupShape_P1
    mov ecx, 16
    cld
    rep movsb

    ; 2. 清空暫存
    mov edi, OFFSET tempShape_P1
    mov ecx, 16
    mov al, 0
    rep stosb

    ; 3. 旋轉公式計算
    mov esi, 0
RotRowLoop_P1:
    cmp esi, 4
    jge DoCopy_P1
    mov edi, 0
RotColLoop_P1:
    cmp edi, 4
    jge RotNextRow_P1
    mov eax, esi
    shl eax, 2
    add eax, edi
    mov ebx, eax
    cmp backupShape_P1[ebx], 1
    jne SkipRot_P1
    mov eax, edi
    shl eax, 2
    mov edx, 3
    sub edx, esi
    add eax, edx
    mov tempShape_P1[eax], 1
SkipRot_P1:
    inc edi
    jmp RotColLoop_P1
RotNextRow_P1:
    inc esi
    jmp RotRowLoop_P1

DoCopy_P1:
    ; 4. 覆蓋與碰撞檢查
    mov esi, OFFSET tempShape_P1
    mov edi, OFFSET curShape_P1
    mov ecx, 16
    rep movsb
    call CheckCollision_P1
    cmp eax, 1
    jne RotDone_P1                      ; 沒撞到 -> 成功
    
    ; 5. 撞到了，退回備份
    mov esi, OFFSET backupShape_P1
    mov edi, OFFSET curShape_P1
    mov ecx, 16
    rep movsb
RotDone_P1:
    popad
    ret
RotatePiece_P1 ENDP

; --- [P1 邏輯] 處理向下掉落、鎖定與死亡判定 ---
UpdateBlockDown_P1 PROC
    cmp isDead_P1, 1                    ; 死亡狀態不處理
    je End_UB_P1

    call EraseCurrentPiece_P1
    inc curY_P1
    call CheckCollision_P1
    .IF eax == 1                        ; 撞到底部或其他方塊
        dec curY_P1
        call LockPiece_P1               ; 鎖定
        call ClearLines_P1              ; 檢查消行
        call DrawBoard_P1               ; 重繪更新後的盤面
        call SpawnPiece_P1              ; 產生新方塊
        
        ; 死亡判定 (一出生就撞)
        call CheckCollision_P1
        .IF eax == 1
            mov isDead_P1, 1            ; 標記死亡
            cmp isDead_P2, 1            ; 檢查對手是否也死了
            je GameOverCalc             ; 都死就結算
        .ENDIF
    .ENDIF
End_UB_P1:
    ret
UpdateBlockDown_P1 ENDP

; --- [P1 邏輯] 消行判定與加分 ---
ClearLines_P1 PROC
    pushad
    mov esi, BOARD_H - 1
CheckRow_P1:
    cmp esi, 0
    jl EndClear_P1
    mov edi, 0
    mov ecx, BOARD_W
CheckFull_P1:
    mov eax, esi
    imul eax, BOARD_W
    add eax, edi
    mov ebx, eax
    cmp Board_P1[ebx], 0                ; 檢查有無空隙
    je NotFull_P1
    inc edi
    loop CheckFull_P1

    ; 該行全滿：加分並更新顯示
    add score_P1, 100
    call DrawScore_P1

    ; 將上方記憶體往下搬移
    mov edi, esi
ShiftDown_P1:
    cmp edi, 0
    je FillTop_P1
    mov eax, edi
    imul eax, BOARD_W
    mov edx, eax
    mov eax, edi
    dec eax
    imul eax, BOARD_W
    mov ebx, eax
    mov ecx, BOARD_W
CopyB_P1:
    mov al, Board_P1[ebx]
    mov Board_P1[edx], al
    inc ebx
    inc edx
    loop CopyB_P1
    dec edi
    jmp ShiftDown_P1

FillTop_P1:
    mov ecx, BOARD_W
    mov ebx, 0
FillZ_P1:
    mov Board_P1[ebx], 0
    inc ebx
    loop FillZ_P1
    jmp CheckRow_P1

NotFull_P1:
    dec esi
    jmp CheckRow_P1
EndClear_P1:
    popad
    ret
ClearLines_P1 ENDP

; --- [P1 邏輯] 碰撞偵測機制 ---
CheckCollision_P1 PROC
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov esi, 0
CheckRowC_P1:
    cmp esi, 4
    jge NoColl_P1
    mov edi, 0
CheckColC_P1:
    cmp edi, 4
    jge NextRowC_P1
    mov ebx, esi
    shl ebx, 2
    add ebx, edi
    cmp curShape_P1[ebx], 1
    jne SkipCheckC_P1
    mov eax, curX_P1
    add eax, edi
    mov edx, curY_P1
    add edx, esi
    cmp eax, 0
    jl FoundColl_P1                     ; 撞左牆
    cmp eax, BOARD_W
    jge FoundColl_P1                    ; 撞右牆
    cmp edx, BOARD_H
    jge FoundColl_P1                    ; 撞地板
    
    ; 檢查是否與盤面原有方塊重疊
    push eax
    mov eax, edx
    imul eax, BOARD_W
    pop ecx
    add eax, ecx
    mov ebx, eax
    cmp Board_P1[ebx], 0
    jne FoundColl_P1
SkipCheckC_P1:
    inc edi
    jmp CheckColC_P1
NextRowC_P1:
    inc esi
    jmp CheckRowC_P1
FoundColl_P1:
    mov eax, 1                          ; 有碰撞回傳 1
    jmp EndCheck_P1
NoColl_P1:
    mov eax, 0                          ; 無碰撞回傳 0
EndCheck_P1:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
CheckCollision_P1 ENDP

; --- [P1 邏輯] 將方塊寫入盤面陣列 ---
LockPiece_P1 PROC
    pushad
    mov esi, 0
LockRow_P1:
    cmp esi, 4
    jge EndLock_P1
    mov edi, 0
LockCol_P1:
    cmp edi, 4
    jge NextLock_P1
    mov ebx, esi
    shl ebx, 2
    add ebx, edi
    cmp curShape_P1[ebx], 1
    jne SkipLock_P1
    mov eax, curY_P1
    add eax, esi
    imul eax, BOARD_W
    mov edx, curX_P1
    add edx, edi
    add eax, edx
    mov ebx, eax
    mov Board_P1[ebx], 1                ; 寫入 1
SkipLock_P1:
    inc edi
    jmp LockCol_P1
NextLock_P1:
    inc esi
    jmp LockRow_P1
EndLock_P1:
    popad
    ret
LockPiece_P1 ENDP

; --- [P1 渲染] 繪製外圍鐵框 ---
DrawBoardBorder_P1 PROC
    mov eax, Gray
    call SetTextColor

    ; 左、右邊框 (雙線 186)
    mov ecx, BOARD_H
    mov al, START_Y
L1_P1:
    mov dl, START_X_P1 - 1
    mov dh, al
    call Gotoxy
    push eax
    mov al, 186
    call WriteChar
    mov dl, START_X_P1 + BOARD_W*2      ; 右框也要乘 2
    call Gotoxy
    mov al, 186
    call WriteChar
    pop eax
    inc al
    loop L1_P1

    ; 底線 (雙線 205)
    mov ecx, BOARD_W*2 + 2
    mov dl, START_X_P1 - 1
    mov dh, START_Y + BOARD_H
L2_P1:
    call Gotoxy
    mov al, 205
    call WriteChar
    inc dl
    loop L2_P1
    ret
DrawBoardBorder_P1 ENDP

; --- [P1 渲染] 繪製盤面 (雙倍寬度) ---
DrawBoard_P1 PROC
    pushad
    mov eax, lightGray
    call SetTextColor
    mov esi, 0
DB_Row_P1:
    cmp esi, BOARD_H
    jge EndDB_P1
    mov edi, 0
DB_Col_P1:
    cmp edi, BOARD_W
    jge NextDB_P1
    
    ; 取得陣列值
    mov eax, esi
    imul eax, BOARD_W
    add eax, edi
    mov ebx, eax

    ; 計算 X 座標 (乘 2 達成雙倍寬，才會變成正方形)
    mov eax, START_X_P1
    mov edx, edi
    shl edx, 1 ; 左移 1 位，也就是*2
    add eax, edx
    mov dl, al

    ; 計算 Y 座標
    mov eax, START_Y
    add eax, esi
    mov dh, al
    call Gotoxy

    ; 依狀態印出色塊或空白
    cmp Board_P1[ebx], 1
    jne Empty_P1
    mov al, BLOCK_CHAR
    call WriteChar
    call WriteChar     ; 印兩次湊正方形
    jmp Skip_P1
Empty_P1:
    mov al, ' '
    call WriteChar
    call WriteChar
Skip_P1:
    inc edi
    jmp DB_Col_P1
NextDB_P1:
    inc esi
    jmp DB_Row_P1
EndDB_P1:
    popad
    ret
DrawBoard_P1 ENDP

; --- [P1 渲染] 繪製正在掉落的方塊 ---
DrawCurrentPiece_P1 PROC
    mov eax, lightCyan
    call SetTextColor
    mov esi, 0
DC_Row_P1:
    cmp esi, 4
    jge EndDC_P1
    mov edi, 0
DC_Col_P1:
    cmp edi, 4
    jge NextDC_P1
    mov ebx, esi
    shl ebx, 2
    add ebx, edi
    cmp curShape_P1[ebx], 1
    jne SkipDC_P1

    ; 計算 X 座標 (乘 2 達成雙倍寬)
    mov eax, START_X_P1
    mov ebx, curX_P1
    shl ebx, 1
    add eax, ebx
    mov ebx, edi
    shl ebx, 1
    add eax, ebx
    mov dl, al

    ; 計算 Y 座標
    mov eax, START_Y
    add eax, curY_P1
    add eax, esi
    mov dh, al
    call Gotoxy

    mov al, BLOCK_CHAR
    call WriteChar
    call WriteChar                      ; 印兩次
SkipDC_P1:
    inc edi
    jmp DC_Col_P1
NextDC_P1:
    inc esi
    jmp DC_Row_P1
EndDC_P1:
    ret
DrawCurrentPiece_P1 ENDP

; --- [P1 渲染] 擦除掉落方塊的殘影 ---
EraseCurrentPiece_P1 PROC
    mov esi, 0
EC_Row_P1:
    cmp esi, 4
    jge EndEC_P1
    mov edi, 0
EC_Col_P1:
    cmp edi, 4
    jge NextEC_P1
    mov ebx, esi
    shl ebx, 2
    add ebx, edi
    cmp curShape_P1[ebx], 1
    jne SkipEC_P1

    ; 計算座標
    mov eax, START_X_P1
    mov ebx, curX_P1
    shl ebx, 1
    add eax, ebx
    mov ebx, edi
    shl ebx, 1
    add eax, ebx
    mov dl, al

    mov eax, START_Y
    add eax, curY_P1
    add eax, esi
    mov dh, al
    call Gotoxy

    mov al, ' '
    call WriteChar
    call WriteChar                      ; 空白也要印兩次
SkipEC_P1:
    inc edi
    jmp EC_Col_P1
NextEC_P1:
    inc esi
    jmp EC_Row_P1
EndEC_P1:
    ret
EraseCurrentPiece_P1 ENDP

; --- [P1 渲染] 繪製分數板 ---
DrawScore_P1 PROC
    pushad
    mov eax, white
    call SetTextColor
    mov dl, START_X_P1
    mov dh, START_Y - 2                 ; 放在邊框上方
    call Gotoxy
    mov edx, OFFSET strScore
    call WriteString                    ; 印出 SCORE:
    mov eax, score_P1
    call WriteDec                       ; 印出數字
    popad
    ret
DrawScore_P1 ENDP



; ==============================================================================
;           PLAYER 2 專屬副程式 (邏輯與 P1 完全對稱，僅替換變數名稱與顏色)
; ==============================================================================

SpawnPiece_P2 PROC
    pushad
    mov curX_P2, 3
    mov curY_P2, 0
    mov eax, 7                  ; 修改：產生 0~6 的亂數 (共7種)
    call RandomRange

    cmp eax, 0
    je Copy_I_P2
    cmp eax, 1
    je Copy_J_P2
    cmp eax, 2
    je Copy_L_P2
    cmp eax, 3
    je Copy_O_P2
    cmp eax, 4
    je Copy_S_P2
    cmp eax, 5
    je Copy_T_P2
    cmp eax, 6
    je Copy_Z_P2
    jmp Copied_P2

Copy_I_P2:
    mov esi, OFFSET Shape_I
    jmp Copied_P2
Copy_J_P2:
    mov esi, OFFSET Shape_J
    jmp Copied_P2
Copy_L_P2:
    mov esi, OFFSET Shape_L
    jmp Copied_P2
Copy_O_P2:
    mov esi, OFFSET Shape_O
    jmp Copied_P2
Copy_S_P2:
    mov esi, OFFSET Shape_S
    jmp Copied_P2
Copy_T_P2:
    mov esi, OFFSET Shape_T
    jmp Copied_P2
Copy_Z_P2:
    mov esi, OFFSET Shape_Z
    jmp Copied_P2

Copied_P2:
    mov edi, OFFSET curShape_P2
    mov ecx, 16
    cld
    rep movsb
    popad
    ret
SpawnPiece_P2 ENDP

RotatePiece_P2 PROC
    pushad
    mov esi, OFFSET curShape_P2
    mov edi, OFFSET backupShape_P2
    mov ecx, 16
    cld
    rep movsb

    mov edi, OFFSET tempShape_P2
    mov ecx, 16
    mov al, 0
    rep stosb

    mov esi, 0
RotRowLoop_P2:
    cmp esi, 4
    jge DoCopy_P2
    mov edi, 0
RotColLoop_P2:
    cmp edi, 4
    jge RotNextRow_P2
    mov eax, esi
    shl eax, 2
    add eax, edi
    mov ebx, eax
    cmp backupShape_P2[ebx], 1
    jne SkipRot_P2
    mov eax, edi
    shl eax, 2
    mov edx, 3
    sub edx, esi
    add eax, edx
    mov tempShape_P2[eax], 1
SkipRot_P2:
    inc edi
    jmp RotColLoop_P2
RotNextRow_P2:
    inc esi
    jmp RotRowLoop_P2

DoCopy_P2:
    mov esi, OFFSET tempShape_P2
    mov edi, OFFSET curShape_P2
    mov ecx, 16
    rep movsb
    call CheckCollision_P2
    cmp eax, 1
    jne RotDone_P2
    mov esi, OFFSET backupShape_P2
    mov edi, OFFSET curShape_P2
    mov ecx, 16
    rep movsb
RotDone_P2:
    popad
    ret
RotatePiece_P2 ENDP

UpdateBlockDown_P2 PROC
    cmp isDead_P2, 1
    je End_UB_P2

    call EraseCurrentPiece_P2
    inc curY_P2
    call CheckCollision_P2
    .IF eax == 1
        dec curY_P2
        call LockPiece_P2
        call ClearLines_P2
        call DrawBoard_P2
        call SpawnPiece_P2
        
        call CheckCollision_P2
        .IF eax == 1
            mov isDead_P2, 1
            cmp isDead_P1, 1
            je GameOverCalc
        .ENDIF
    .ENDIF
End_UB_P2:
    ret
UpdateBlockDown_P2 ENDP

ClearLines_P2 PROC
    pushad
    mov esi, BOARD_H - 1
CheckRow_P2:
    cmp esi, 0
    jl EndClear_P2
    mov edi, 0
    mov ecx, BOARD_W
CheckFull_P2:
    mov eax, esi
    imul eax, BOARD_W
    add eax, edi
    mov ebx, eax
    cmp Board_P2[ebx], 0
    je NotFull_P2
    inc edi
    loop CheckFull_P2

    add score_P2, 100
    call DrawScore_P2

    mov edi, esi
ShiftDown_P2:
    cmp edi, 0
    je FillTop_P2
    mov eax, edi
    imul eax, BOARD_W
    mov edx, eax
    mov eax, edi
    dec eax
    imul eax, BOARD_W
    mov ebx, eax
    mov ecx, BOARD_W
CopyB_P2:
    mov al, Board_P2[ebx]
    mov Board_P2[edx], al
    inc ebx
    inc edx
    loop CopyB_P2
    dec edi
    jmp ShiftDown_P2

FillTop_P2:
    mov ecx, BOARD_W
    mov ebx, 0
FillZ_P2:
    mov Board_P2[ebx], 0
    inc ebx
    loop FillZ_P2
    jmp CheckRow_P2

NotFull_P2:
    dec esi
    jmp CheckRow_P2
EndClear_P2:
    popad
    ret
ClearLines_P2 ENDP

CheckCollision_P2 PROC
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov esi, 0
CheckRowC_P2:
    cmp esi, 4
    jge NoColl_P2
    mov edi, 0
CheckColC_P2:
    cmp edi, 4
    jge NextRowC_P2
    mov ebx, esi
    shl ebx, 2
    add ebx, edi
    cmp curShape_P2[ebx], 1
    jne SkipCheckC_P2
    mov eax, curX_P2
    add eax, edi
    mov edx, curY_P2
    add edx, esi
    cmp eax, 0
    jl FoundColl_P2
    cmp eax, BOARD_W
    jge FoundColl_P2
    cmp edx, BOARD_H
    jge FoundColl_P2
    push eax
    mov eax, edx
    imul eax, BOARD_W
    pop ecx
    add eax, ecx
    mov ebx, eax
    cmp Board_P2[ebx], 0
    jne FoundColl_P2
SkipCheckC_P2:
    inc edi
    jmp CheckColC_P2
NextRowC_P2:
    inc esi
    jmp CheckRowC_P2
FoundColl_P2:
    mov eax, 1
    jmp EndCheck_P2
NoColl_P2:
    mov eax, 0
EndCheck_P2:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
CheckCollision_P2 ENDP

LockPiece_P2 PROC
    pushad
    mov esi, 0
LockRow_P2:
    cmp esi, 4
    jge EndLock_P2
    mov edi, 0
LockCol_P2:
    cmp edi, 4
    jge NextLock_P2
    mov ebx, esi
    shl ebx, 2
    add ebx, edi
    cmp curShape_P2[ebx], 1
    jne SkipLock_P2
    mov eax, curY_P2
    add eax, esi
    imul eax, BOARD_W
    mov edx, curX_P2
    add edx, edi
    add eax, edx
    mov ebx, eax
    mov Board_P2[ebx], 1
SkipLock_P2:
    inc edi
    jmp LockCol_P2
NextLock_P2:
    inc esi
    jmp LockRow_P2
EndLock_P2:
    popad
    ret
LockPiece_P2 ENDP

DrawBoardBorder_P2 PROC
    mov eax, Gray
    call SetTextColor
    mov ecx, BOARD_H
    mov al, START_Y
L1_P2:
    mov dl, START_X_P2 - 1
    mov dh, al
    call Gotoxy
    push eax
    mov al, 186
    call WriteChar
    mov dl, START_X_P2 + BOARD_W*2
    call Gotoxy
    mov al, 186
    call WriteChar
    pop eax
    inc al
    loop L1_P2

    mov ecx, BOARD_W*2 + 2
    mov dl, START_X_P2 - 1
    mov dh, START_Y + BOARD_H
L2_P2:
    call Gotoxy
    mov al, 205
    call WriteChar
    inc dl
    loop L2_P2
    ret
DrawBoardBorder_P2 ENDP

DrawBoard_P2 PROC
    pushad
    mov eax, lightGray
    call SetTextColor
    mov esi, 0
DB_Row_P2:
    cmp esi, BOARD_H
    jge EndDB_P2
    mov edi, 0
DB_Col_P2:
    cmp edi, BOARD_W
    jge NextDB_P2
    mov eax, esi
    imul eax, BOARD_W
    add eax, edi
    mov ebx, eax
    mov eax, START_X_P2
    mov edx, edi
    shl edx, 1
    add eax, edx
    mov dl, al
    mov eax, START_Y
    add eax, esi
    mov dh, al
    call Gotoxy
    cmp Board_P2[ebx], 1
    jne Empty_P2
    mov al, BLOCK_CHAR
    call WriteChar
    call WriteChar
    jmp Skip_P2
Empty_P2:
    mov al, ' '
    call WriteChar
    call WriteChar
Skip_P2:
    inc edi
    jmp DB_Col_P2
NextDB_P2:
    inc esi
    jmp DB_Row_P2
EndDB_P2:
    popad
    ret
DrawBoard_P2 ENDP

DrawCurrentPiece_P2 PROC
    mov eax, Yellow                     ; P2 使用黃色方塊區別
    call SetTextColor
    mov esi, 0
DC_Row_P2:
    cmp esi, 4
    jge EndDC_P2
    mov edi, 0
DC_Col_P2:
    cmp edi, 4
    jge NextDC_P2
    mov ebx, esi
    shl ebx, 2
    add ebx, edi
    cmp curShape_P2[ebx], 1
    jne SkipDC_P2
    mov eax, START_X_P2
    mov ebx, curX_P2
    shl ebx, 1
    add eax, ebx
    mov ebx, edi
    shl ebx, 1
    add eax, ebx
    mov dl, al
    mov eax, START_Y
    add eax, curY_P2
    add eax, esi
    mov dh, al
    call Gotoxy
    mov al, BLOCK_CHAR
    call WriteChar
    call WriteChar
SkipDC_P2:
    inc edi
    jmp DC_Col_P2
NextDC_P2:
    inc esi
    jmp DC_Row_P2
EndDC_P2:
    ret
DrawCurrentPiece_P2 ENDP

EraseCurrentPiece_P2 PROC
    mov esi, 0
EC_Row_P2:
    cmp esi, 4
    jge EndEC_P2
    mov edi, 0
EC_Col_P2:
    cmp edi, 4
    jge NextEC_P2
    mov ebx, esi
    shl ebx, 2
    add ebx, edi
    cmp curShape_P2[ebx], 1
    jne SkipEC_P2
    mov eax, START_X_P2
    mov ebx, curX_P2
    shl ebx, 1
    add eax, ebx
    mov ebx, edi
    shl ebx, 1
    add eax, ebx
    mov dl, al
    mov eax, START_Y
    add eax, curY_P2
    add eax, esi
    mov dh, al
    call Gotoxy
    mov al, ' '
    call WriteChar
    call WriteChar
SkipEC_P2:
    inc edi
    jmp EC_Col_P2
NextEC_P2:
    inc esi
    jmp EC_Row_P2
EndEC_P2:
    ret
EraseCurrentPiece_P2 ENDP

DrawScore_P2 PROC
    pushad
    mov eax, white
    call SetTextColor
    mov dl, START_X_P2
    mov dh, START_Y - 2
    call Gotoxy
    mov edx, OFFSET strScore
    call WriteString
    mov eax, score_P2
    call WriteDec
    popad
    ret
DrawScore_P2 ENDP

; =========================================================
; 繪製計時器 (初始 Label)
; =========================================================
DrawTimerInit PROC
    pushad
    mov eax, white
    call SetTextColor
    mov dl, 27              ; X座標：放在 P1 與 P2 盤面中間的空隙
    mov dh, 1               ; Y座標：放在螢幕最上方
    call Gotoxy
    mov edx, OFFSET strTime
    call WriteString
    popad
    ret
DrawTimerInit ENDP

; =========================================================
; 繪製計時器 (倒數秒數)
; =========================================================
DrawTimerValue PROC
    pushad
    mov eax, lightRed       ; 剩餘時間使用醒目的紅色
    call SetTextColor
    mov dl, 33              ; X座標：放在 "TIME: " 後面
    mov dh, 1
    call Gotoxy
    mov eax, lastSeconds
    call WriteDec           ; 印出剩餘秒數
    mov edx, OFFSET strSec
    call WriteString        ; 印出 "s  " 並清除殘影
    popad
    ret
DrawTimerValue ENDP

; ==============================================================================
; [輔助工具] 隱藏系統游標
; ==============================================================================
HideCursor PROC
    pushad
    INVOKE GetStdHandle, -11 ; 索取存取權(api)
    INVOKE SetConsoleCursorInfo, eax, ADDR cursorInfo ; 隱藏輸入游標(api)
    popad
    ret
HideCursor ENDP

END main