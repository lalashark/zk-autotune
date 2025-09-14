pragma circom 2.1.6;

// N 越大越重：先用 512 起手，若太快就加到 1024/2048
template HeavyChain(N) {
    signal input a;
    signal output z;

    signal inter[N+1];
    inter[0] <== a;

    for (var i = 0; i < N; i++) {
        // 非線性：平方 + 1，會產生乘法約束
        inter[i+1] <== inter[i] * inter[i] + 1;
    }

    z <== inter[N];
}

component main = HeavyChain(512);
