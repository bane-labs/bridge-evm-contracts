import { deployAll } from "./deploy/deployAll";

async function main() {
    await deployAll();
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
