import { BigNumberish, Signer } from "ethers";

export async function fundAddress(signer: Signer, address: string, amount: BigNumberish, log = true) {
    const tx = signer.sendTransaction({
        to: address,
        value: amount
    });
    tx.then((tx) => {
        if (log) {
            console.log("Funded Address: ", address);
        }
    });
    (await tx).wait();
}
