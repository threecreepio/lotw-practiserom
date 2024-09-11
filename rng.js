
function stepRNG(input) {
    let output = [...input];
    let x = input[2];
    let y = input[1];
    output[0] = y;
    y <<= 1;
    x <<= 1;
    if (y > 0xFF) { x += 1; y &= 0xFF; }
    y += 1;
    if (y > 0xFF) { x += 1; y &= 0xFF; }
    y += output[1];
    x += output[2];
    if (y > 0xFF) { x += 1; y &= 0xFF; }
    x = (x + output[0]) & 0x7F;
    output[2] = x;
    output[1] = y;
    return output;
}


let seen = new Set();

//let seed = [0x3E, 0xBB, 0x1A];
let seed = [0x00, 0x28, 0x7F];
let result = [...seed];
let i = 0;
console.log(result.join(','));
for (i=0; i<0x10000000; ++i) {
    result = stepRNG(result);
    console.log(result.join(','));
    let key = result.join('.');
    if (seen.has(key)) break;
    seen.add(key);
    //if (result[0] === seed[0] && result[1] === seed[1] && result[2] === seed[2]) break;
}


