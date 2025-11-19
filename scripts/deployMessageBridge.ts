import { deployMessageBridgeContracts } from "./deploy/messageBridge";

async function main() {
    await deployMessageBridgeContracts();
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
