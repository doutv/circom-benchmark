pragma circom 2.1.5;

include "../../circuits/p256.circom";

component main {public [a, b]} = P256AddUnequal(43, 6);
