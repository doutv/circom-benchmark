# Benchmark Groth16 Circom Circuits
Require: rapidsnark

1. Set `.env`
```
cp example.env .env
```
2. Compile the circuits and Benchmark
```sh
./1-prepare.sh rsa rsa

./2-benchmark.sh rsa rsa
./2-benchmark.sh keccak256 keccak256

for size in {100k,400k,1200k,1600k,3200k}
do
    ./2-benchmark.sh complex-circuit complex-circuit-$size-$size
    sleep 0.1
done
```

## Credits
Scripts from https://github.com/zkmopro/mopro