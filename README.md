# Tetris

俄羅斯方塊 雙人對戰 (Assembly)

<img width="373" height="320.5" alt="image" src="https://github.com/user-attachments/assets/7497f7a8-a902-4371-ba1f-e671f79c1eec" />

開發環境：  MASM 與 Irvine32 Library 

遊玩操作說明： <br>
P1 使用 WASD，W旋轉、AD左右移動、S向下加速 <br>
P2 使用方向鍵，up旋轉、left/right左右移動、down向下加速 <br>

關於使用AI與網路資料: 
1. 因為是團體專題，加上組合語言可讀性、行數較多，有請AI幫忙排版
2. 一些防呆設定，或找不到bug的error，會讓AI提出建議，再結合自身經驗進行更改
3. 一些特殊的api如: 抓取時間、Gotoxy(定位座標)、隱藏游標等，查詢做法再結合到程式裡面
4. 比較不易理解的功能實作，有請AI提供架構，在完成內部編寫，如: 方塊旋轉+碰墻機制、方塊下落(渲染)等區塊
