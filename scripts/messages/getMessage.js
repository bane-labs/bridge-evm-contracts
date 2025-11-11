const {getMessageBridgeFromEnv} = require('../utils/addresses');
const {ethers} = require('hardhat');


async function main() {
  const envNonce = process.env.NONCE || (() => {
    throw new Error('Please set the NONCE environment variable');
  })();
  const nonce = parseInt(envNonce);
  const messageBridge = await getMessageBridgeFromEnv();

  let {encodedMetadata, rawMessage} = await messageBridge.getEvmMessage(nonce);
  console.log('Encoded Metadata:', encodedMetadata);
  const abiCoder =  new ethers.AbiCoder();
  const metadataStructAbi = ["tuple(uint8 type, uint256 timestamp, address sender, bool storeResult)"];
  let decodedMetadata = abiCoder.decode(metadataStructAbi, encodedMetadata);
  console.log('Decoded Metadata:', decodedMetadata);

  console.log('Raw Message:', rawMessage);
  if (decodedMetadata[0].type === 0n) {
    console.log('Decoding Call Structure...');
    const callStructAbi = ["tuple(address target, bool allowFailure, uint256 value, bytes callData)"];
    let decodedCall = abiCoder.decode(callStructAbi, rawMessage);
    console.log('Decoded Call Structure:', decodedCall);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
