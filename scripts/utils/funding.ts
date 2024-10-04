import { BigNumberish, Signer } from "ethers";

export async function fundAddress(signer: Signer, address: string, amount: BigNumberish) {
    const tx = signer.sendTransaction({
        to: address,
        value: amount
    });
    tx.then((tx) => {
        console.log("Funded Address: ", address);
    });
    (await tx).wait();
}
