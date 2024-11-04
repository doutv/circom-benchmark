npm install -g snarkjs

pushd ecdsa-p256/circuits/circom-pairing
npm i
popd

# create a .env
# 1-prepare.sh will download a large ptau file to your Desktop if you don't have it
export PTAU_DIR=~/Desktop
export PTAU_NUM=21

# build circuit, generate provingKey (zkey) and witness
# ~30mins trusted setup on MacBook M1 Pro
./1-prepare.sh ecdsa-p256 ecdsa-p256

cd ecdsa-p256/target
# export vkey
snarkjs zkev ecdsa-p256_final.zkey ecdsa-p256.vkey

# generate proof
snarkjs g16p ecdsa-p256_final.zkey build/ecdsa-p256.wtns proof.json public.json

# verify proof
snarkjs g16v ecdsa-p256.vkey public.json proof.json