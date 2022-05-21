const chai = require("chai");
const { ethers } = require("hardhat");
const wasm_tester = require("circom_tester").wasm;
const buildPoseidon = require("circomlibjs").buildPoseidon;

const F1Field = require("ffjavascript").F1Field;
const Scalar = require("ffjavascript").Scalar;
exports.p = Scalar.fromString(
  "21888242871839275222246405745257275088548364400416034343698204186575808495617"
);
const Fr = new F1Field(exports.p);
const assert = chai.assert;

function bufToBn(buf) {
  let hex = [];
  const u8 = Uint8Array.from(buf);

  u8.forEach(function (i) {
    let h = i.toString(16);
    if (h.length % 2) {
      h = "0" + h;
    }
    hex.push(h);
  });

  return BigInt("0x" + hex.join(""));
}

describe("MastermindVariation", function () {
  let mastermind;
  let poseidonJs;

  beforeEach(async function () {
    const MastermindVariation = await ethers.getContractFactory("Verifier");
    mastermind = await MastermindVariation.deploy();
    await mastermind.deployed();
    poseidonJs = await buildPoseidon();
  });

  it("accepts a valid solution", async function () {
    const circuit = await wasm_tester(
      "contracts/circuits/MastermindVariation.circom"
    );
    await circuit.loadConstraints();

    const salt = bufToBn(ethers.utils.randomBytes(32));
    const solution = ["1", "2", "3", "4"];
    const guess = ["1", "5", "6", "7"];
    const solutionHash = poseidonJs.F.toObject(poseidonJs([salt, ...solution]));

    const INPUT = {
      solution,
      guess,
      givenSum: "10",
      numHit: "1",
      numBlow: "0",
      solutionHash,
      privSalt: salt,
    };

    const witness = await circuit.calculateWitness(INPUT, true);

    assert(Fr.eq(Fr.e(witness[0]), Fr.e(1)));
    assert(Fr.eq(Fr.e(witness[1]), solutionHash));
  });
});
