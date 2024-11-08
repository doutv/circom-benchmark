# batch-ecdsa-secp256r1

Implementation of batch ECDSA signatures in circom for the P-256 curve. The code in this repo allows you to prove that you know valid ECDSA signatures for n messages and n corresponding public keys.

> These circuits are not audited, and this is not intended to be used as a library for production-grade applications.

## Overview

This repository provides proof-of-concept implementations of ECDSA operations on the P-256 curve in circom. These implementations are for demonstration purposes only.

- `circuits` : Contains the signature aggregation circuit. The `P256BatchECDSAVerifyNoPubkeyCheck(n,k,b)` function takes in the number of batches as `b`.
- `scripts` : Contains `generateSampleSignature.ts` which generates `p256` signatures, converts the bigint values to `6` `43-bit` register arrays and dumps it into `output/input_${batch_size}.json`.
- `test` : Includes the `batch_ecdsa.ts` file with two test cases & `circuits` folder with template instantiations of different batches.

## Information

This implementation is based on the concept of [Using Randomizers for Batch Verification of ECDSA Signatures](https://eprint.iacr.org/2012/582.pdf).

The verification equation for ECDSA Signatures is
```math
R = ( h * s^{-1}) * G + ( r * s^{-1}) * Q
```
where `Q` is the public key.

When aggregating a bunch of signatures, the equation becomes
```math
\sum_{i=0}^{b} R_i = (\sum_{i=0}^{b} u) G + (\sum_{i=0}^{b} v * Q)
```
where
```math
u = h * s^{-1},
```
and
```math
v = r * s^{-1}
```
`b` = number of signatures

We get randomly chosen zero multipliers `t1`, `t2`, `t3` and so on to verify if the following equality holds :

```math
\sum_{i=0}^{b} t_i R_i = (\sum_{i=0}^{b} t_i u) G + (\sum_{i=0}^{b} t_i v * Q)
```

Many attacks on batch verification schemes can be eliminated by using these randomizers. However, the computation of `b` scalar multiplications significantly reduce the performance gained by batching.

For batch ECDSA, we need to be familiar with ECDSA* in which the user provides `r'` ( in addition to `{r, s}`). `r'` is called as `rprime` or `y co-ordinate of R`. While computing the algebraic expression might look expensive, there are several fair optimizations for computing ecdsa eg. the window method.

> Note : [puma314/batch-ecdsa](https://github.com/puma314/batch-ecdsa) uses the same trick to lower proving costs by 3x

## Prerequisites

Make sure you have the following dependencies pre-installed

- [python3.8](https://tech.sadaalomma.com/ubuntu/how-to-downgrade-python-3-10-to-3-8-ubuntu/)
- [circom](https://docs.circom.io/getting-started/installation/)
- [yarn](https://classic.yarnpkg.com/lang/en/docs/install/#windows-stable)
- [ts-node](https://www.npmjs.com/package/ts-node#installation)
- [cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html)

Due to the large nature of these circuits, we use [Best practices for Large circuits](https://hackmd.io/@yisun/BkT0RS87q#Setup-from-scratch) & perform the setup from scratch in order to avoid most of the memory issues.

## Installing dependencies

- Run `git submodule update --init --recursive`
- Run `yarn` at the top level to install npm dependencies
- Run `yarn` inside of `circuits/circom-ecdsa-p256` to install npm dependencies for the `circom-ecdsa-p256` library.
- Run `yarn` inside of `circuits/circom-ecdsa-p256/circuits/circom-pairing` to install npm dependencies for the `circom-pairing` library.

## Generating & Verifying proofs

1. Simply run the following command in the root directory to download the powers of Tau

```bash
wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_${K_SIZE}.ptau
mkdir ptau
mv powersOfTau28_hez_final_${K_SIZE}.ptau ptau/
```

2. Run the bash script using the following command to generate & verify proofs using a wasm witness generator and snarkjs prover

```bash
/bin/bash scripts/build_wasm.sh
```

## Circuits Description

- `batch_ecdsa.circom` : This contains `P256BatchECDSAVerifyNoPubkeyCheck(n, k, b)` which takes in `r`, `rprime`, `s`, `msghash` and `pubkey` for `b` batches. The randomizer `t` is then calculated by hashing all the inputs using `Poseidon` hash function. Then we compute `b` powers of `t` . The individual components of the aggregated ECDSA equation is calculated to compute the following and perform an equality check :
```math
\sum_{i=0}^{b} t_i (R_i - v * Q)  =  \sum_{i=0}^{b} t_i (u * G)
```

- `p256_lc.circom` : The algebraic sum is computed using `P256LinearCombination` template which takes in points and coefficients of an algebraic equation. A Linear equation is achieved by generating a lookup table with elliptic curve operations, with all the evaluations aggregated to output an elliptic curve point in the end.

- `p256_ops.circom` : This file contains some of the p256 curve operations used in `p256_lc.circom`


## Benchmarks

All benchmarks were run on an 16-core 3.0GHz, 32G RAM machine (AWS c5.4xlarge instance) with 400G of swap space using the WASM witness generator with the snarkjs prover.

|                                      | verify2 | verify4 | verify8 | verify16  |
| ------------------------------------ | ------- | ------- | ------- | --------- |
| Constraints                          | 2.5M    | 3.6M    | 5.7M    | 10.1M     |
| Circuit compilation                  | 51s     | 75      | 105s    | 180s      |
| Witness generation                   | 150s    | 221s    | 364s    | 600s      |
| Trusted setup phase 2 key generation | 238s    | 445s    | 1177s   | 2459s     |
| Trusted setup phase 2 contribution   | 215s    | 251s    | 459s    | 864s      |
| Proving key size                     | 1.41G   | 1.89G   | 3.12G   | 5.56G     |
| Proving key verification             | 469s    | 718s    | 1588s   | 2895s     |
| Proving time                         | 165s    | 283s    | 664s    | 1553s     |
| Proof verification time              | <1s     | 2s      | 1s      | <1s       |

> Note : Using a C++ witness generator and rapid snark prover, one can speed up the process of proof generation. I haven't been able to do it due to this peculiar [Segmentation Error](https://github.com/iden3/circom/issues/127).

## Testing

To test the circuit, simply run ``yarn test``

```bash
$ yarn test
yarn run v1.22.19
$ NODE_OPTIONS=--max_old_space_size=0 mocha --timeout 0 -r ts-node/register 'test/**/*.ts'


  ECDSABatchVerifyNoPubkeyCheck
    ✔ testing correct sig (163226ms)
    ✔ testing incorrect sig (114501ms)


  2 passing (6m)

Done in 350.79s.
```

## Acknowledgements

- The circuit uses [circom-ecdsa-p256](https://github.com/privacy-scaling-explorations/circom-ecdsa-p256) as submodule.
- The inspiration for this project is taken from [batch-ecdsa](https://github.com/puma314/batch-ecdsa)
