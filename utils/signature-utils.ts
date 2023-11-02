import { ethers } from "hardhat";
import { Signer, Signature } from "ethers";

export async function getSignature(signer: Signer, msg: any): Promise<Signature> {
    return ethers.Signature.from(await signer.signMessage(msg));
}

/** 
 * @param msg the message to sign.
 * @param which the index of the validators to sign. Use 1-7 here. Index 0 represents the relayer.
 * @returns the promise of a signature array with the specified validator's signatures of the message.
 */
export async function getValidatorSignatures(msg: any, which: number[] = [1, 2, 3, 4, 5]): Promise<Signature[]> {
    const [
        _,
        validator1,
        validator2,
        validator3,
        validator4,
        validator5,
        validator6,
        validator7
    ] = await ethers.getSigners();
    let validators: Signer[] = [_, validator1, validator2, validator3, validator4, validator5, validator6, validator7];
    let sigs: Signature[] = [];
    for (let i of which) {
        sigs.push(await getSignature(validators[i], msg));
    }
    return sigs;
}
