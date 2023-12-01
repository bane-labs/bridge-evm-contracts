import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getValidatorSignatures } from "../utils/signature-utils";

import {
    // relayer, validator1, validator2, validator3, validator4, validator5, validator6, validator7,
    to1, to2, to3, to4, to5, to6, to7, to8, to9, to0,
    toEthDecimals, toNeoDecimals, hashDepositOrWithdrawal, fundContract, computeRoot, validator1, validator2, validator3
} from "./helper";

import { getMerkleProof } from "../utils/merkletree-utils";

describe("App Logs Bridge contract", function () {
    async function deployBridgeFixture() {
        const [
            relayer,
            validator1,
            validator2,
            validator3,
            validator4,
            validator5,
            validator6,
            validator7
        ] = await ethers.getSigners();
        const appLogsBridgeContract = await ethers.deployContract("AppLogsBridgeContract");
        await appLogsBridgeContract.waitForDeployment();
        return {
            appLogsBridgeContract,
            relayer,
            validator1,
            validator2,
            validator3,
            validator4,
            validator5,
            validator6,
            validator7
        }
    }

    describe("Deployment", function () {
        it("Should have the right relayer", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            expect(await appLogsBridgeContract.relayer()).to.equal(relayer.address);
        });

        it("Should have the right validators", async function () {
            const { appLogsBridgeContract, validator1, validator2, validator3, validator4, validator5, validator6, validator7 } = await loadFixture(deployBridgeFixture);
            expect(await appLogsBridgeContract.validators(0)).to.equal(validator1.address);
            expect(await appLogsBridgeContract.validators(1)).to.equal(validator2.address);
            expect(await appLogsBridgeContract.validators(2)).to.equal(validator3.address);
            expect(await appLogsBridgeContract.validators(3)).to.equal(validator4.address);
            expect(await appLogsBridgeContract.validators(4)).to.equal(validator5.address);
            expect(await appLogsBridgeContract.validators(5)).to.equal(validator6.address);
            expect(await appLogsBridgeContract.validators(6)).to.equal(validator7.address);
            await expect(appLogsBridgeContract.validators(7)).to.be.revertedWithoutReason();
        });
    });

    describe("Deposit", async function () {
        it("Deposit the first Nonce", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const depositData1 = { nonce: 1, amount: 100000000n, to: relayer.address };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResult1.root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            const DepositWithProof = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };
            const tx = await appLogsBridgeContract.connect(relayer).deposit(proofResult1.root, signatures, [DepositWithProof]);
            await expect(tx).to.changeEtherBalances([appLogsBridgeContract, depositData1.to], [-toEthDecimals(depositData1.amount), toEthDecimals(depositData1.amount)]);
            await expect(tx).to.emit(appLogsBridgeContract, "Deposit").withArgs(depositData1.nonce, depositData1.amount, depositData1.to);
            expect(await appLogsBridgeContract.depositNonce()).to.equal(depositData1.nonce);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(proofResult1.root);
        });

        it("Deposit with Multiple Continous Nonce", async function () {
            const { appLogsBridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const data = [
                { nonce: 1, amount: 100000000n, to: relayer.address },
                { nonce: 2, amount: 200000000n, to: validator1.address }
            ];
            const datahash = [];
            for (let i = 0; i < 2; i++) {
                datahash.push(await hashDepositOrWithdrawal(data[i].nonce, data[i].amount, data[i].to));
            }
            const proofResultArray = [];
            for (let i = 0; i < 2; i++) {
                proofResultArray.push(await getMerkleProof(datahash, datahash[i]));
            }
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResultArray[0].root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);
            const depositandproof = [];
            for (let i = 0; i < 2; i++) {
                depositandproof.push({ to: data[i].to, amount: data[i].amount, nonce: data[i].nonce, path: proofResultArray[i].path, proof: proofResultArray[i].proof });
            }
            const tx = await appLogsBridgeContract.connect(relayer).deposit(proofResultArray[0].root, signatures, depositandproof);

            await expect(tx).to.changeEtherBalances([appLogsBridgeContract, data[0].to, data[1].to], [-toEthDecimals(data[0].amount + data[1].amount), toEthDecimals(data[0].amount), toEthDecimals(data[1].amount)]);
            for (let i = 0; i < 2; i++) {
                await expect(tx).to.emit(appLogsBridgeContract, "Deposit").withArgs(data[i].nonce, data[i].amount, data[i].to);
            }
            expect(await appLogsBridgeContract.depositNonce()).to.equal(2);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(proofResultArray[0].root);
        });

        it("Deposit with Multiple Times with different Nonce Array", async function () {
            const { appLogsBridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const depositData1 = { nonce: 1, amount: 100000000n, to: relayer.address };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResult1.root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            const depositWithProof1 = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };
            const tx = await appLogsBridgeContract.connect(relayer).deposit(proofResult1.root, signatures, [depositWithProof1]);
            await expect(tx).to.changeEtherBalances([appLogsBridgeContract, depositData1.to], [-toEthDecimals(depositData1.amount), toEthDecimals(depositData1.amount)]);
            await expect(tx).to.emit(appLogsBridgeContract, "Deposit").withArgs(depositData1.nonce, depositData1.amount, depositData1.to);
            expect(await appLogsBridgeContract.depositNonce()).to.equal(depositData1.nonce);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(proofResult1.root);

            //calculate the root and signatures for the second deposit (nonce=2,3)
            const data_secondtime = [
                { nonce: 2, amount: 100000000n, to: relayer.address },
                { nonce: 3, amount: 200000000n, to: validator1.address }
            ];
            const datahash_secondtime = [];
            for (let i = 0; i < 2; i++) {
                datahash_secondtime.push(await hashDepositOrWithdrawal(data_secondtime[i].nonce, data_secondtime[i].amount, data_secondtime[i].to));
            }
            const proofResultArray_secondtime = [];
            for (let i = 0; i < 2; i++) {
                proofResultArray_secondtime.push(await getMerkleProof([hash1].concat(datahash_secondtime), datahash_secondtime[i]));
            }
            const new_root = proofResultArray_secondtime[0].root;
            const encodeRoot2 = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures2 = await getValidatorSignatures(ethers.getBytes(encodeRoot2), [1, 2, 3, 4, 5]);

            const depositandproof2 = [];
            for (let i = 0; i < 2; i++) {
                depositandproof2.push({ to: data_secondtime[i].to, amount: data_secondtime[i].amount, nonce: data_secondtime[i].nonce, path: proofResultArray_secondtime[i].path, proof: proofResultArray_secondtime[i].proof });
            }
            const tx2 = await appLogsBridgeContract.connect(relayer).deposit(new_root, signatures2, depositandproof2);

            await expect(tx2).to.changeEtherBalances([appLogsBridgeContract, data_secondtime[0].to, data_secondtime[1].to], [-toEthDecimals(data_secondtime[0].amount + data_secondtime[1].amount), toEthDecimals(data_secondtime[0].amount), toEthDecimals(data_secondtime[1].amount)]);
            await expect(tx2).to.emit(appLogsBridgeContract, "Deposit").withArgs(data_secondtime[0].nonce, data_secondtime[0].amount, data_secondtime[0].to);
            await expect(tx2).to.emit(appLogsBridgeContract, "Deposit").withArgs(data_secondtime[1].nonce, data_secondtime[1].amount, data_secondtime[1].to);

            expect(await appLogsBridgeContract.depositNonce()).to.equal(data_secondtime[1].nonce);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(new_root);
        });

        it("Deposit with insufficient fund of Contract", async function () {
            const { appLogsBridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const data = [
                { nonce: 1, amount: 100000000n, to: relayer.address },
                { nonce: 2, amount: 200000000n, to: validator1.address }
            ];
            const datahash = [];
            for (let i = 0; i < 2; i++) {
                datahash.push(await hashDepositOrWithdrawal(data[i].nonce, data[i].amount, data[i].to));
            }
            const proofResultArray = [];
            for (let i = 0; i < 2; i++) {
                proofResultArray.push(await getMerkleProof(datahash, datahash[i]));
            }
            const root = proofResultArray[0].root;
            const encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot), [1, 2, 3, 4, 5]);
            const depositandproof = [];
            for (let i = 0; i < 2; i++) {
                depositandproof.push({ to: data[i].to, amount: data[i].amount, nonce: data[i].nonce, path: proofResultArray[i].path, proof: proofResultArray[i].proof });
            }
            const tx = await appLogsBridgeContract.connect(relayer).deposit(root, signatures, depositandproof);
            // check the balance is not change for the recipient address; but the root and depositNonce are both updated
            await expect(tx).to.changeEtherBalances([appLogsBridgeContract, data[0].to, data[1].to], [0, 0, 0]);
            expect(await appLogsBridgeContract.depositNonce()).to.equal(data[1].nonce);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(root);
            for (let i = 0; i < 2; i++) {
                expect(await appLogsBridgeContract.claimableTo(data[i].nonce)).to.equal(data[i].to);
                expect(await appLogsBridgeContract.claimableAmount(data[i].nonce)).to.equal(data[i].amount);
                await expect(tx).to.emit(appLogsBridgeContract, "Claimable").withArgs(data[i].nonce, data[i].amount, data[i].to);
            }

        });

        it("Deposit When Recipient is Contract", async function () {
            const { appLogsBridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);
            const testpayablecontract = await ethers.deployContract("TestPayableContract");
            await testpayablecontract.waitForDeployment();

            const data = [
                { nonce: 1, amount: 100000000n, to: relayer.address },
                { nonce: 2, amount: 200000000n, to: await testpayablecontract.getAddress() }
            ];
            const datahash = [];
            for (let i = 0; i < 2; i++) {
                datahash.push(await hashDepositOrWithdrawal(data[i].nonce, data[i].amount, data[i].to));
            }
            const proofResultArray = [];
            for (let i = 0; i < 2; i++) {
                proofResultArray.push(await getMerkleProof(datahash, datahash[i]));
            }
            const root = proofResultArray[0].root;
            const encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot), [1, 2, 3, 4, 5]);
            const depositandproof = [];
            for (let i = 0; i < 2; i++) {
                depositandproof.push({ to: data[i].to, amount: data[i].amount, nonce: data[i].nonce, path: proofResultArray[i].path, proof: proofResultArray[i].proof });
            }
            const tx = await appLogsBridgeContract.connect(relayer).deposit(root, signatures, depositandproof);
            // check the balance is not change for the recipient address; but the root and depositNonce are both updated
            await expect(tx).to.changeEtherBalances([appLogsBridgeContract, data[0].to, data[1].to], [-toEthDecimals(data[0].amount), toEthDecimals(data[0].amount), 0]);
            expect(await appLogsBridgeContract.depositNonce()).to.equal(data[1].nonce);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(root);
            expect(await appLogsBridgeContract.claimableTo(data[1].nonce)).to.equal(data[1].to);
            expect(await appLogsBridgeContract.claimableAmount(data[1].nonce)).to.equal(data[1].amount);
            await expect(tx).to.emit(appLogsBridgeContract, "Deposit").withArgs(data[0].nonce, data[0].amount, data[0].to);
            await expect(tx).to.emit(appLogsBridgeContract, "Claimable").withArgs(data[1].nonce, data[1].amount, data[1].to);
        });

        it("Deposit When Deposit Length is Equal to 10", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const dataArray = [];
            let hashArray = [];
            for (let i = 0; i < 10; i++) {
                const data = { nonce: i + 1, amount: 100000000n, to: relayer.address };
                dataArray.push(data);
                hashArray.push(await hashDepositOrWithdrawal(data.nonce, data.amount, data.to));
            }
            const proofResultArray = [];
            const depositandproof = [];
            for (let i = 0; i < 10; i++) {
                proofResultArray.push(await getMerkleProof(hashArray, hashArray[i]));
                depositandproof.push({ to: dataArray[i].to, amount: dataArray[i].amount, nonce: dataArray[i].nonce, path: proofResultArray[i].path, proof: proofResultArray[i].proof });
            }
            const root = proofResultArray[0].root;
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await appLogsBridgeContract.connect(relayer).deposit(root, signatures, depositandproof);
            await expect(tx).to.changeEtherBalances([appLogsBridgeContract, relayer.address], [-toEthDecimals(dataArray[0].amount * 10n), toEthDecimals(dataArray[0].amount * 10n)]);
            expect(await appLogsBridgeContract.depositNonce()).to.equal(10);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(root);
            for (let i = 0; i < 10; i++) {
                await expect(tx).to.emit(appLogsBridgeContract, "Deposit").withArgs(dataArray[i].nonce, dataArray[i].amount, dataArray[i].to);
            }
        });

        it("Should revert with empty proofs", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(appLogsBridgeContract.connect(relayer).deposit(ethers.ZeroHash, [], [])).to.be.revertedWith("At least 1 deposit is required.");
        });

        it("Should revert with proofs length greater than 10", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const depositLength = 11;
            const dataArray = [];
            let hashArray = [];
            for (let i = 0; i < depositLength; i++) {
                const data = { nonce: i + 1, amount: 100000000n, to: relayer.address };
                dataArray.push(data);
                hashArray.push(await hashDepositOrWithdrawal(data.nonce, data.amount, data.to));
            }
            const proofResultArray = [];
            const depositandproof = [];
            for (let i = 0; i < depositLength; i++) {
                proofResultArray.push(await getMerkleProof(hashArray, hashArray[i]));
                depositandproof.push({ to: dataArray[i].to, amount: dataArray[i].amount, nonce: dataArray[i].nonce, path: proofResultArray[i].path, proof: proofResultArray[i].proof });
            }
            const root = proofResultArray[0].root;
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            await expect(appLogsBridgeContract.connect(relayer).deposit(root, signatures, depositandproof)).to.be.revertedWith("Too many deposits provided.");

        });

        it("Should revert with the wrong first nonce", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(appLogsBridgeContract.connect(relayer).deposit(ethers.ZeroHash, [], [{ nonce: 2, amount: 100000000n, to: relayer.address, proof: [], path: 0 }])).to.be.revertedWith("Only the next nonce is allowed in the first proof.");
        });

        it("Should revert when nonce is not subsequent", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const depositandproof = [
                { nonce: 1, amount: 100000000n, to: relayer.address, proof: [], path: 0 },
                { nonce: 3, amount: 100000000n, to: relayer.address, proof: [], path: 0 }
            ];
            await expect(appLogsBridgeContract.connect(relayer).deposit(ethers.ZeroHash, [], depositandproof)).to.be.revertedWith("The nonces of the proofs must be subsequent.");
        });

        it("Should revert when signature length less than 5", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const depositData1 = { nonce: 1, amount: 100000000n, to: relayer.address };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResult1.root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [2, 3, 4, 5]);

            const DepositWithProof = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };

            await expect(appLogsBridgeContract.connect(relayer).deposit(proofResult1.root, signatures, [DepositWithProof])).to.be.revertedWith("Invalid number of signatures.");
        });

        it("Should revert when signature length is 5 but with two duplicate signature", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const depositData1 = { nonce: 1, amount: 100000000n, to: relayer.address };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResult1.root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 1, 3, 4, 5]);

            const DepositWithProof = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };

            await expect(appLogsBridgeContract.connect(relayer).deposit(proofResult1.root, signatures, [DepositWithProof])).to.be.revertedWith("Invalid or insufficient validator signatures.");
        });

        it("Should revert when signature length is 5 but not with order", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const depositData1 = { nonce: 1, amount: 100000000n, to: relayer.address };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResult1.root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 6, 5]);

            const DepositWithProof = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };

            await expect(appLogsBridgeContract.connect(relayer).deposit(proofResult1.root, signatures, [DepositWithProof])).to.be.revertedWith("Invalid or insufficient validator signatures.");
        });

        it("Should revert when signature verify failed", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const depositData1 = { nonce: 1, amount: 100000000n, to: relayer.address };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResult1.root]);
            //index 0 is the relayer, so the signature is invalid
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [0, 2, 3, 4, 5]);

            const DepositWithProof = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };

            await expect(appLogsBridgeContract.connect(relayer).deposit(proofResult1.root, signatures, [DepositWithProof])).to.be.revertedWith("Invalid or insufficient validator signatures.");
        });

        it("Should revert when verify proof failed", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const depositData1 = { nonce: 1, amount: 100000000n, to: relayer.address };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const invalid_root = ethers.randomBytes(32);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [invalid_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            const DepositWithProof = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };

            await expect(appLogsBridgeContract.connect(relayer).deposit(invalid_root, signatures, [DepositWithProof])).to.be.revertedWith("Invalid proof provided for a deposit.");
        });

    });

    describe("Withdraw", function () {
        it("withdraw only once", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const withdrawData = { nonce: 1, amount: ethers.parseEther("1"), to: relayer.address };
            const tx = await appLogsBridgeContract.connect(relayer).withdraw(withdrawData.to, { value: withdrawData.amount });

            expect(await appLogsBridgeContract.withdrawalNonce()).to.be.equal(1);
            await expect(tx).to.emit(appLogsBridgeContract, "Withdrawal").withArgs(1, toNeoDecimals(withdrawData.amount), relayer.address, relayer.address);

        });

        it("withdraw multiple times", async function () {
            const { appLogsBridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const withdrawData1 = { nonce: 1, amount: ethers.parseEther("1"), to: relayer.address };
            const tx = await appLogsBridgeContract.connect(relayer).withdraw(withdrawData1.to, { value: withdrawData1.amount });
            await expect(tx).to.changeEtherBalances([appLogsBridgeContract, relayer.address], [ethers.parseEther("1"), -ethers.parseEther("1")]);

            const withdrawData2 = { nonce: 2, amount: ethers.parseEther("2"), to: validator1.address };

            const tx2 = await appLogsBridgeContract.connect(validator1).withdraw(withdrawData2.to, { value: withdrawData2.amount });

            expect(await appLogsBridgeContract.withdrawalNonce()).to.be.equal(2);
            await expect(tx2).to.emit(appLogsBridgeContract, "Withdrawal").withArgs(2, toNeoDecimals(withdrawData2.amount), withdrawData2.to, validator1.address);
            await expect(tx2).to.changeEtherBalances([appLogsBridgeContract, validator1.address], [ethers.parseEther("2"), -ethers.parseEther("2")]);

        });

        it("withdraw with amount edge case", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const withdrawData = { nonce: 1, amount: ethers.parseEther("1.00000001"), to: relayer.address };
            const tx = await appLogsBridgeContract.connect(relayer).withdraw(withdrawData.to, { value: withdrawData.amount });

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData.nonce, toNeoDecimals(withdrawData.amount), relayer.address);
            const new_withdrawRoot = await computeRoot(ethers.ZeroHash, hashWithdrawData1);

            expect(await appLogsBridgeContract.withdrawalNonce()).to.be.equal(1);
            await expect(tx).to.emit(appLogsBridgeContract, "Withdrawal").withArgs(1, toNeoDecimals(withdrawData.amount), relayer.address, relayer.address);
            await expect(tx).to.changeEtherBalances([appLogsBridgeContract, relayer], [ethers.parseEther("1.00000001"), -ethers.parseEther("1.00000001")]);
        });

        it("withdraw with the wrong amount", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            await expect(appLogsBridgeContract.connect(relayer).withdraw(relayer, { value: ethers.parseEther("0.000000001") })).to.be.revertedWith("Only amounts with 8 non-zero decimals allowed for withdrawal");
        });

        it("withdraw with the amount smaller than minWithdrawalAmount", async function () {
            const { appLogsBridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            await expect(appLogsBridgeContract.connect(relayer).withdraw(relayer, { value: ethers.parseEther("0.9") })).to.be.revertedWith("Smaller than minimum withdrawal amount");
        });
    });

    describe("Claim", function () {
        it("Claim successful for EOA account", async function () {
            const { appLogsBridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const depositData1 = { nonce: 1, amount: 100000000n, to: relayer.address };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResult1.root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            const DepositWithProof = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };
            const tx = await appLogsBridgeContract.connect(relayer).deposit(proofResult1.root, signatures, [DepositWithProof]);
            await expect(tx).to.changeEtherBalances([appLogsBridgeContract, depositData1.to], [0, 0]);
            expect(await appLogsBridgeContract.depositNonce()).to.equal(depositData1.nonce);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(proofResult1.root);
            expect(await appLogsBridgeContract.claimableTo(depositData1.nonce)).to.equal(depositData1.to);
            expect(await appLogsBridgeContract.claimableAmount(depositData1.nonce)).to.equal(depositData1.amount);

            await fundContract(appLogsBridgeContract, relayer);
            const claim_tx1 = await appLogsBridgeContract.connect(validator1).claim(depositData1.nonce);

            expect(await appLogsBridgeContract.claimableTo(depositData1.nonce)).to.equal(ethers.ZeroAddress);
            expect(await appLogsBridgeContract.claimableAmount(depositData1.nonce)).to.equal(0);
            await expect(claim_tx1).to.emit(appLogsBridgeContract, "Claimed").withArgs(depositData1.nonce, depositData1.amount, depositData1.to);
            await expect(claim_tx1).to.changeEtherBalances([appLogsBridgeContract, depositData1.to], [-toEthDecimals(depositData1.amount), toEthDecimals(depositData1.amount)]);

        });

        it("Claim successful for payable contract", async function () {
            const { appLogsBridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);
            const testpayableContract = await ethers.deployContract("TestPayableContract");
            await testpayableContract.waitForDeployment();

            const depositData1 = { nonce: 1, amount: 100000000n, to: await testpayableContract.getAddress() };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResult1.root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            const DepositWithProof = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };
            const tx1 = await appLogsBridgeContract.connect(relayer).deposit(proofResult1.root, signatures, [DepositWithProof]);
            await expect(tx1).to.changeEtherBalances([appLogsBridgeContract, depositData1.to], [0, 0]);
            expect(await appLogsBridgeContract.depositNonce()).to.equal(depositData1.nonce);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(proofResult1.root);
            expect(await appLogsBridgeContract.claimableTo(depositData1.nonce)).to.equal(depositData1.to);
            expect(await appLogsBridgeContract.claimableAmount(depositData1.nonce)).to.equal(depositData1.amount);

            const claim_tx1 = await appLogsBridgeContract.connect(validator1).claim(depositData1.nonce);

            expect(await appLogsBridgeContract.claimableTo(depositData1.nonce)).to.equal(ethers.ZeroAddress);
            expect(await appLogsBridgeContract.claimableAmount(depositData1.nonce)).to.equal(0);
            await expect(claim_tx1).to.emit(appLogsBridgeContract, "Claimed").withArgs(depositData1.nonce, depositData1.amount, depositData1.to);
            await expect(claim_tx1).to.changeEtherBalances([appLogsBridgeContract, depositData1.to], [-toEthDecimals(depositData1.amount), toEthDecimals(depositData1.amount)]);

        });

        it("Fail to claim due to Contract not payable", async function () {
            const { appLogsBridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);
            await fundContract(appLogsBridgeContract, relayer);

            const depositData1 = { nonce: 1, amount: 100000000n, to: await appLogsBridgeContract.getAddress() };
            const hash1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const proofResult1 = await getMerkleProof([hash1], hash1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [proofResult1.root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            const DepositWithProof = { to: depositData1.to, amount: depositData1.amount, nonce: depositData1.nonce, path: proofResult1.path, proof: proofResult1.proof };
            const tx1 = await appLogsBridgeContract.connect(relayer).deposit(proofResult1.root, signatures, [DepositWithProof]);
            await expect(tx1).to.changeEtherBalances([appLogsBridgeContract, depositData1.to], [0, 0]);
            expect(await appLogsBridgeContract.depositNonce()).to.equal(depositData1.nonce);
            expect(await appLogsBridgeContract.depositRoot()).to.equal(proofResult1.root);
            expect(await appLogsBridgeContract.claimableTo(depositData1.nonce)).to.equal(depositData1.to);
            expect(await appLogsBridgeContract.claimableAmount(depositData1.nonce)).to.equal(depositData1.amount);

            await expect(appLogsBridgeContract.connect(validator1).claim(depositData1.nonce)).to.be.revertedWith("Transfer failed");
        });

        it("Fail to claim for not existed nonce in the claim table", async function () {
            const { appLogsBridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);
            await expect(appLogsBridgeContract.connect(validator1).claim(3)).to.be.revertedWith("No claimable funds");
        });

    });
});