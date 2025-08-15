const { getMessageBridgeFromEnv } = require("../utils/addresses");
const { DEFAULT_TX_OVERRIDES } = require("../utils/constants");

async function getExecutionResult(messageBridge, nonce) {
    const { success, returnData } = await messageBridge.getResult(nonce, DEFAULT_TX_OVERRIDES);
    console.log("Execution result:");
    console.log(success);
    console.log(returnData);
}

async function main() {
    const nonce = 1;
    const messageBridge = await getMessageBridgeFromEnv();
    await getExecutionResult(messageBridge, nonce);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
