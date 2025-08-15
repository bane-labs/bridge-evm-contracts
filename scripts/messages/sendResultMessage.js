const { ethers } = require("hardhat");
const { fundIfLocalNetwork } = require("../utils/network");
const { getMessageBridgeFromEnv } = require("../utils/addresses");
const { getOwner } = require("../utils/wallet");
const { DEFAULT_TX_OVERRIDES } = require("../utils/constants");

async function sendTestMessageResult(messageBridge) {
    const sender = getOwner(ethers.provider);
    await fundIfLocalNetwork([sender.address]);

    const nonce = 1;
    await messageBridge.sendResultMessage(nonce, DEFAULT_TX_OVERRIDES);
}

async function main() {
    const messageBridge = await getMessageBridgeFromEnv();
    await sendTestMessageResult(messageBridge);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
