pragma circom 2.1.5;

include "./circuits/ecdsa.circom";

component main {public [msghash, pubkey]} = ECDSAVerifyNoPubkeyCheck(43, 6);
