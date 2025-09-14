pragma circom 2.1.6;

template HeavyAdd(N) {
    signal input a;
    signal input b;
    signal input c;        // public input
    signal inter[N+1];

    // 這兩行都用 "==="，確保真的產生約束
    inter[0] === a + b;

    for (var i = 0; i < N; i++) {
        inter[i+1] === inter[i] + 1;
    }

    // 把公開輸入 c 也約束起來
    c === inter[N];
}

// 先從 1<<14 開始，有感的負載；通了再加大
component main { public [c] } = HeavyAdd(1 << 14);


