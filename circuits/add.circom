pragma circom 2.1.6;

template AddPublicC() {
    signal input a;
    signal input b;
    signal input c;   // 要公開的值用「輸入」宣告（2.1.x 的 public 只能掛在 input 上）

    signal sum;
    sum <== a + b;    // 計算 a+b

    // 非線性約束： (sum - c)^2 = 0  =>  sum == c
    signal d;
    d <== sum - c;
    signal q;
    q <== d * d;
    q === 0;
}
component main { public [c] } = AddPublicC();
