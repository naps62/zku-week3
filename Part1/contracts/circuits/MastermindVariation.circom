pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

// if s == 0 returns in[0]
// if s == 1 returns in[1]
template Mux() {
    signal input in[2];
    signal input s;
    signal output out;

    s * (1 - s) === 0;
    out <== (in[1] - in[0])*s + in[0];
}

// Cmoputes a mastermind game where the code breaker can optionally provide an extra hint
// by publishing the sum of all elements in the code
//
// This circuit works by receiving an optional givenSum value
// if givenSum > 0, then the circuit ensures that givenSum equals the sum of the entire solution
//
// Importantly, it doesn't enforce that the sum of guess values should equal as well
// Since the code breaker may want to try other combinations in other to gain information
template MastermindVariation() {
  // Public inputs
  signal input guess[4];
  signal input numBlow;
  signal input numHit;
  signal input solutionHash;
  signal input givenSum; // 0, or the public sum of the solution values

  // private inputs
  signal input solution[4];
  signal input privSalt;

  signal output solutionHashOut;

  var i = 0;
  var j = 0;
  var k = 0;
  var equalIdx = 0;
  var sumGuesses = 0;
  var sumSolutions = 0;

  // constrain guess & solution values
  component guessLessThan[4];
  component solutionLessThan[4];
  component equalGuess[6];
  component equalSoln[6];

  for(i=0; i<4; i++) {
    guessLessThan[i] = LessThan(4);
    guessLessThan[i].in[0] <== guess[i];
    guessLessThan[i].in[1] <== 10;
    guessLessThan[i].out === 1;

    solutionLessThan[i] = LessThan(4);
    solutionLessThan[i].in[0] <== solution[i];
    solutionLessThan[i].in[1] <== 10;
    solutionLessThan[i].out === 1;

    // check that digits are unique
    for (k=i+1; k<4; k++) {
        equalGuess[equalIdx] = IsEqual();
        equalGuess[equalIdx].in[0] <== guess[j];
        equalGuess[equalIdx].in[1] <== guess[k];
        equalGuess[equalIdx].out === 0;
        equalSoln[equalIdx] = IsEqual();
        equalSoln[equalIdx].in[0] <== solution[j];
        equalSoln[equalIdx].in[1] <== solution[k];
        equalSoln[equalIdx].out === 0;
        equalIdx += 1;
    }

    // compute sums of solution
    sumSolutions += solution[i];
  }

  // if givenSum > 0
  component sumGreaterThan = GreaterThan(4);
  sumGreaterThan.in[0] <== givenSum;
  sumGreaterThan.in[1] <== 0;

  component validSum = Mux();
  validSum.s <== sumGreaterThan.out;
  validSum.in[0] <== 0;
  validSum.in[1] <== sumSolutions;

  // givenSum > 0 ? givenSum == sumSolutions : givenSum == 0
  givenSum === validSum.out;

  // count hit & blow
  var hit = 0;
  var blow = 0;
  component equalHB[16];
  for (j = 0; j < 4; j++) {
    for(k = 0; k < 4; k++) {
      equalHB[4*j+k] = IsEqual();
      equalHB[4*j+k].in[0] <== guess[j];
      equalHB[4*j+k].in[1] <== solution[k];
      blow += equalHB[4*j+k].out;
      if (j == k) {
        hit += equalHB[4*j+k].out;
        blow -= equalHB[4*j+k].out;
      }
    }
  }

  // Create a constraint around the number of hit
  component equalHit = IsEqual();
  equalHit.in[0] <== numHit;
  equalHit.in[1] <== hit;
  equalHit.out === 1;
  
  // Create a constraint around the number of blow
  component equalBlow = IsEqual();
  equalBlow.in[0] <== numBlow;
  equalBlow.in[1] <== blow;
  equalBlow.out === 1;

  // Verify that the hash of the private solution matches pubSolnHash
  component poseidon = Poseidon(5);
  poseidon.inputs[0] <== privSalt;
  poseidon.inputs[1] <== solution[0];
  poseidon.inputs[2] <== solution[1];
  poseidon.inputs[3] <== solution[2];
  poseidon.inputs[4] <== solution[3];

  solutionHashOut <== poseidon.out;
  solutionHashOut === solutionHash;
}

component main = MastermindVariation();