# Benchmark Groth16 Circom Circuits
Require: rapidsnark

1. Set `.env` file: ptau and rapidsnark
2. Compile the circuits and Benchmark
```sh
./1-prepare.sh
./2-Benchmark.sh rsa rsa
./2-Benchmark.sh keccak256 keccak256

for size in {100k,400k,1200k,1600k,3200k}
do
    ./2-Benchmark.sh complex-circuit complex-circuit-$size-$size
done
```