
好的 👍 我幫你整理一個簡潔專業的 `README.md` 範本，你可以直接覆蓋或 append 到你現有的檔案：


# zk-autotune

自動化 Circom 電路調優工具。  
目標是讓使用者只需提供電路與輸入，就能自動完成 **編譯 → setup → 單次驗證 → 並行調優** 的完整流程。

---

## ✨ 功能特色
- 一鍵執行 (`run.sh`)：自動完成編譯、setup、驗證、調優。
- 並行測試 (`tune.sh`)：利用 GNU Parallel 測量不同並行度 (J 值) 下的延遲與吞吐量。
- 支援多個電路：
  - `add.circom` (簡單加法器)
  - `heavy_chain.circom` (長鏈運算)

---

## 📂 專案結構
```
.
├── circuits/           # Circom 電路
│   ├── add.circom
│   ├── heavy\_chain.circom
│   └── heavy\_chain.inputs
├── scripts/            # 執行腳本
│   ├── compile.sh
│   ├── setup\_keys.sh
│   ├── run\_one.sh
│   ├── run.sh
│   ├── tune.sh
│   └── utils.sh
├── Dockerfile          # 容器化環境
├── README.md           # 專案文件
└── .gitignore

```

> `build/`, `results/`, `tmp/` 等資料夾已忽略，不會 push 到 GitHub。

---

## 🚀 使用方式

### 1. 建立 Docker 環境
```bash
docker build -t zk-autotune .
docker run -it --rm -v $PWD:/work zk-autotune
````

### 2. 編譯並 setup 電路

```bash
/work/scripts/compile.sh /work/circuits/add.circom add
/work/scripts/setup_keys.sh add
```

### 3. 執行單次驗證

```bash
/work/scripts/run_one.sh add 3 4 7
```

### 4. 一鍵調優

```bash
/work/scripts/run.sh add 3 4 7
```

或指定參數：

```bash
/work/scripts/run.sh --reps 5 --max-j 16 heavy_chain 3
```

---

## 📊 成果範例

### add.circom

```
Baseline (J=1):         1.250s
最佳延遲  (Latency):     J=16 → 0.282s/proof  (Speedup x4.438)
最佳吞吐  (Throughput):  J=16 → 3.550 proof/s
```

### heavy\_chain.circom

```
Baseline (J=1):         1.348s
最佳延遲  (Latency):     J=16 → 0.287s/proof  (Speedup x4.691)
最佳吞吐  (Throughput):  J=16 → 3.480 proof/s
```

---

## 📚 參考資料

* [Circom Documentation](https://docs.circom.io/)
* [snarkjs](https://github.com/iden3/snarkjs)
* [GNU Parallel](https://www.gnu.org/software/parallel/)

---

