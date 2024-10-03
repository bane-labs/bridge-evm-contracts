import { deployBridgeContracts } from "./deploy/bridge";

async function main() {
    await deployBridgeContracts();
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
