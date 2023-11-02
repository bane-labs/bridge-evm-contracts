import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getValidatorSignatures } from "../utils/signature-utils";
import {
  // relayer, validator1, validator2, validator3, validator4, validator5, validator6, validator7,
  to1, to2, to3, to4, to5, to6, to7, to8, to9, to0,
  toEthDecimals, concatRoots, fundContract
} from "./helper";
import { createMerkleTree } from "../utils/merkletree-utils";

const proof1 = { nonce: 1n, to: "0x71be63f3384f5fb98995898a86b02fb2426c5788", amount: 100000000n, proof: [], root: "0x59ae401a5501394bd7d87d6b4d501afc6e64ef47d24363536ca16e6cd31faebd" }
const proof2 = { nonce: 2n, to: "0xfabb0ac9d68b0b445fb7357272ff202c5651694a", amount: 100000000n, proof: ["0x59ae401a5501394bd7d87d6b4d501afc6e64ef47d24363536ca16e6cd31faebd"], root: "0xdea468a22b4eb491b3f18b1c2d539501953e60b2851523fc75175cf1c5f75153" }
const proof3 = { nonce: 3n, to: "0x1cbd3b2770909d4e10f157cabc84c7264073c9ec", amount: 300000000n, proof: ["0xdea468a22b4eb491b3f18b1c2d539501953e60b2851523fc75175cf1c5f75153"], root: "0xd05016744b17b82c46623d348d65eef830822cf51100237f20b04ec0c206b8e8" }
const proof4 = { nonce: 4n, to: "0xdf3e18d64bc6a983f673ab319ccae4f1a57c7097", amount: 400000000n, proof: ["0xb454beb7e1b63ecd12835f6833ff48ab63ac9c2b3a000b1799bd1ddd0f6261e5", "0xdea468a22b4eb491b3f18b1c2d539501953e60b2851523fc75175cf1c5f75153"], root: "0x70e499e1b407c091cab1a43e215a2cff3017855d75f73b78daeb981f0ac39298" }
const proof5 = { nonce: 5n, to: "0xcd3b766ccdd6ae721141f452c550ca635964ce71", amount: 500000000n, proof: ["0x70e499e1b407c091cab1a43e215a2cff3017855d75f73b78daeb981f0ac39298"], root: "0x1efece6a859d7da73f27672c4399c0c9e773269fe223e6fff05a482760e82ab2" }
const proof6 = { nonce: 6n, to: "0x2546bcd3c84621e976d8185a91a922ae77ecec30", amount: 600000000n, proof: ["0xe026389e4abc675005024c2b83ce86ff1d7f8b43322d0f8fb069af3f4cedfe55", "0x70e499e1b407c091cab1a43e215a2cff3017855d75f73b78daeb981f0ac39298"], root: "0xbaef769b13c1c794bebc19beb093eb344982f60d923a49302b66dc8ef869e1e2" }
const proof7 = { nonce: 7n, to: "0xbda5747bfd65f08deb54cb465eb87d40e51b197e", amount: 700000000n, proof: ["0x9636a1d5204491ba9f0dac81ce44f14552ac83b017af25185abd4b689fa9a819", "0x70e499e1b407c091cab1a43e215a2cff3017855d75f73b78daeb981f0ac39298"], root: "0xf0d91f6d88db656e9c2b5a5f17563245c635d3cc16e917bef8751623f6947ea7" }
const proof8 = { nonce: 8n, to: "0xdd2fd4581271e230360230f9337d5c0430bf44c0", amount: 100000000n, proof: ["0x18bde32bc9aaeaa86d4dd4bbd4f89385bcb534dd45535a89f2f6b994144010f2", "0x9636a1d5204491ba9f0dac81ce44f14552ac83b017af25185abd4b689fa9a819", "0x70e499e1b407c091cab1a43e215a2cff3017855d75f73b78daeb981f0ac39298"], root: "0x5f84714c206f0318e7436c5fbd4d6e417c41902da75a6fc493054812faedf0a0" }
const proof9 = { nonce: 9n, to: "0x8626f6940e2eb28930efb4cef49b2d1f2c9c1199", amount: 100000000n, proof: ["0x5f84714c206f0318e7436c5fbd4d6e417c41902da75a6fc493054812faedf0a0"], root: "0xa598cbda096ed7a2e6de0b1d448989e312ec3527caf7f3def90bc780820e7334" }
const proof10 = { nonce: 10n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xd3bb6e32bdb9aad2141bc945539b098fcdbc0e8904d96b277c54fc2235302dcd", "0x5f84714c206f0318e7436c5fbd4d6e417c41902da75a6fc493054812faedf0a0"], root: "0xd7cda352c20dad18977d9fc364f3c933bf2d51c9bcfa44f2d8acc28252907fab" }
const proof11 = { nonce: 11n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x17172a47d76ee136c031ef4c3323913680629255be3d30c9184d9b8a362b2631", "0x5f84714c206f0318e7436c5fbd4d6e417c41902da75a6fc493054812faedf0a0"], root: "0x58002b4028391067e2024cf14d26f2af5d69457d97974f755339d2aef3974c6b" }
const proof12 = { nonce: 12n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x6dd34cc7e8cfb67ea73ddfb297ab76f702aa8467ccb2a59450500195f8da90ed", "0x17172a47d76ee136c031ef4c3323913680629255be3d30c9184d9b8a362b2631", "0x5f84714c206f0318e7436c5fbd4d6e417c41902da75a6fc493054812faedf0a0"], root: "0x06ec12f87ba01784b007dfc955d856deda017019e0f5322da8b65f955fbffeaa" }
const proof13 = { nonce: 13n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x23425153202f91042345f2daa95d75542ec54d976ed05813db6f15201bed725c", "0x5f84714c206f0318e7436c5fbd4d6e417c41902da75a6fc493054812faedf0a0"], root: "0x75c313313dc370edb3346710ac2ab4fb51845101075c306901fb9c8501b36e6c" }
const proof14 = { nonce: 14n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xbf696881f47255de1235d42dd729d83a7de3bf3b666e0985798a559959b5063e", "0x23425153202f91042345f2daa95d75542ec54d976ed05813db6f15201bed725c", "0x5f84714c206f0318e7436c5fbd4d6e417c41902da75a6fc493054812faedf0a0"], root: "0x169007ea1aeea4dbe421df0b1b5cf4cb9122968a119bcbab1466a068fc99fc44" }
const proof15 = { nonce: 15n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x9648d7f6e7b08ffae87a8f36c46f5790318f88f1b8dace6d1986ace06f0c7d3b", "0x23425153202f91042345f2daa95d75542ec54d976ed05813db6f15201bed725c", "0x5f84714c206f0318e7436c5fbd4d6e417c41902da75a6fc493054812faedf0a0"], root: "0xaa5ad31e49373841b71c11c4a5349f6dfe74e4bbfbfdab45316c2bbf054ac02a" }
const proof16 = { nonce: 16n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x044890ae30e72492843edc5a2eff8b4fe5784233a12003e5f8f1cd61c9b7e2f6", "0x9648d7f6e7b08ffae87a8f36c46f5790318f88f1b8dace6d1986ace06f0c7d3b", "0x23425153202f91042345f2daa95d75542ec54d976ed05813db6f15201bed725c", "0x5f84714c206f0318e7436c5fbd4d6e417c41902da75a6fc493054812faedf0a0"], root: "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f" }
const proof17 = { nonce: 17n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0xb0824f7975d56fabe069ab63f8583544716b0808fb8e884859981383b89cb9b3" }
const proof18 = { nonce: 18n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x3addf4d2161b7f75d26be83ad42b7eb7ec41bfa3313103db3eb7bb804f3d2506", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0x9d62ab567de4e935126b6a51bab4463d8238f710f45afc8e3d401779f67b9d92" }
const proof19 = { nonce: 19n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xf7046a4f7cce069f54e819836e5d64c210c819896b33b11df4bcd0a432e3fc3c", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0xef80955c47d5d3c6a2aad0e120da255f67ed1a9e8e5548a2863a626d5c4b4903" }
const proof20 = { nonce: 20n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xbe78d91921199b92967b3c3b236236993e4c54044097827a51927b381436070a", "0xf7046a4f7cce069f54e819836e5d64c210c819896b33b11df4bcd0a432e3fc3c", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0x1b09e7d3c6b9dadbdfbd6b8b64c6966f7c6085e5c0ebe2b3a7329c3dd19f308c" }
const proof21 = { nonce: 21n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x31eb526f280ce7eb1b941f4b1ffca4e52a94060cda52179d82d67731ec102d1a", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0xca54ecf235fe495f0b9691b48f3eeeb1ca45b0b5ef7b2a6bddefdc352b706d23" }
const proof22 = { nonce: 22n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x33830f0d57da7ca5b9bb50bd29a4abbe49eb139a1f418b16c53654132abed029", "0x31eb526f280ce7eb1b941f4b1ffca4e52a94060cda52179d82d67731ec102d1a", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0x240db4608168f8efd86833533db8410f474ec392017e881038f5cf9e999c2dfb" }
const proof23 = { nonce: 23n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x58ff731183deed8d52384df6c68c75462ef8fec3a981438da41da4190f87e344", "0x31eb526f280ce7eb1b941f4b1ffca4e52a94060cda52179d82d67731ec102d1a", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0xa6f47f953c2894e57f0e7db1a12bf4bc7f4fa15d3748f794ceea6e79e4d93e46" }
const proof24 = { nonce: 24n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xb23bab37ca8373e76ccd8cf3d995622068bca72db903faac6e2823488462d20d", "0x58ff731183deed8d52384df6c68c75462ef8fec3a981438da41da4190f87e344", "0x31eb526f280ce7eb1b941f4b1ffca4e52a94060cda52179d82d67731ec102d1a", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0x8b552fdf46205853aa39e944e920f42a54d470f03926fa869763275e2634adac" }
const proof25 = { nonce: 25n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xe7c1fc26da7c9a0c3d4ffbca76cca4972c6f110dbd3251b67ba30b7ce9ad9db5", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0x4888fcce6f0059a2ca0c7ef488bf1b99a9c99716ee3c00e159caa3b303b8f239" }
const proof26 = { nonce: 26n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xb44f4c2da25ba92913a8cd5a2f821c4f1e5fb250d398dccafdfd44508801c158", "0xe7c1fc26da7c9a0c3d4ffbca76cca4972c6f110dbd3251b67ba30b7ce9ad9db5", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0xe9bce6aa9721148673a1e0e07d99a149d57ba13537250b4c20a4e80d3140f6ad" }
const proof27 = { nonce: 27n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x6be896a7864a85afe757aed3da756b3119ebe3fca7268123d764901f6a67eb73", "0xe7c1fc26da7c9a0c3d4ffbca76cca4972c6f110dbd3251b67ba30b7ce9ad9db5", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0x71bc293f79a8c98a8a9376689eabdf670712e7c9794f66ca7ac47d8ceb80fee3" }
const proof28 = { nonce: 28n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x5b7725deec024136e2561dbcc03e8931751e13df338720d32131cc1732ff4eb6", "0x6be896a7864a85afe757aed3da756b3119ebe3fca7268123d764901f6a67eb73", "0xe7c1fc26da7c9a0c3d4ffbca76cca4972c6f110dbd3251b67ba30b7ce9ad9db5", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0x2a240e0c30929e954cdd45fbdf78a3508a037d6469801ca03e07cf4cdebdc5af" }
const proof29 = { nonce: 29n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x7e134b86544a0a02b815abea382109442d9e2817ccf1da2bb87de72749e378a1", "0xe7c1fc26da7c9a0c3d4ffbca76cca4972c6f110dbd3251b67ba30b7ce9ad9db5", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0x3466e0ce921d6ab3febc55f122b127aa950dfd738ac844f14efdee66f9f2b65f" }
const proof30 = { nonce: 30n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xd43ea852718cb08a221a8cd9fdafc7126aa89e802eecbc213561579eacf9e62f", "0x7e134b86544a0a02b815abea382109442d9e2817ccf1da2bb87de72749e378a1", "0xe7c1fc26da7c9a0c3d4ffbca76cca4972c6f110dbd3251b67ba30b7ce9ad9db5", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0x00ab3b977efd08ca80d16834d0164d79bde8504c618724662da8e0e948e0bf5f" }
const proof31 = { nonce: 31n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x780ccda59c90dc9c878460b061cc658cf96774a8861466cd49b2b9386b2c9035", "0x7e134b86544a0a02b815abea382109442d9e2817ccf1da2bb87de72749e378a1", "0xe7c1fc26da7c9a0c3d4ffbca76cca4972c6f110dbd3251b67ba30b7ce9ad9db5", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0xd5afa8d5ae1348f73275c57a9b72cdca5fe8165d99861ae26a368c370b8992d4" }
const proof32 = { nonce: 32n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x44d348c1e812cd73039cd831d0ceefa4e38284745dd8a9a1c2511f74db004648", "0x780ccda59c90dc9c878460b061cc658cf96774a8861466cd49b2b9386b2c9035", "0x7e134b86544a0a02b815abea382109442d9e2817ccf1da2bb87de72749e378a1", "0xe7c1fc26da7c9a0c3d4ffbca76cca4972c6f110dbd3251b67ba30b7ce9ad9db5", "0x73b60f681f9facba612ed0fa0e43235b3034fc13d35cb102061294b8792c151f"], root: "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f" }
const proof33 = { nonce: 33n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0xcd1fb7f534602b11c0c2e2eb0cf382b0776a01ae6da90eb9deb19cecc60c9c1f" }
const proof34 = { nonce: 34n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x94169acb421fa079bcab55af241cc4d60f0d9959bc99278b0b5e494123efbf51", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x67d65dad48ee210d3a57740f66a38232cccf07604e4dc048c67c3121540e7aaf" }
const proof35 = { nonce: 35n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x006b56e3c601672121f2c1e6540e590e71040e26a0eadf80474baf0c556a6cd4", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0xc5b74d7f6f91c1ae03074349770323b07310d63a2849960465c5494e8be59110" }
const proof36 = { nonce: 36n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x46b70f91a8f7c1349f12ea9cf8719cdaa2da5b0da32695df284e356c58c8cc86", "0x006b56e3c601672121f2c1e6540e590e71040e26a0eadf80474baf0c556a6cd4", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x2d41ae70767390ecb7648c533bb5ab6e5e477c51fb202184f7c1ddd28d0f46e3" }
const proof37 = { nonce: 37n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xb643b2d7e8368b64dedee4365e5c6df487df4cf12bd4bf7e941f2ef2104f14f3", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0xabd039124d5f51c01631b599f44647291de58efe378700f2e63b18f4d5497a6b" }
const proof38 = { nonce: 38n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x98cdfe5b06bfd5599e46a51ee52e6ed3367ef4c62139d3acb5732f21d2fd5d2b", "0xb643b2d7e8368b64dedee4365e5c6df487df4cf12bd4bf7e941f2ef2104f14f3", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0xd9b32ea090387c39c1b28a0b3a36badcb514c6c30bb47a4f691ec1254264edb6" }
const proof39 = { nonce: 39n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x79fcd87d09f7936b92eb68574156f188fedee9de961bd640fa47af9dc6c9a6ab", "0xb643b2d7e8368b64dedee4365e5c6df487df4cf12bd4bf7e941f2ef2104f14f3", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x0b27d054fcca699a73a7cfddd1b2ac60aa121e66ddb0904f8ccb766d88ea4a35" }
const proof40 = { nonce: 40n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xcdc156e04222d2ddf24ec852357782768bae269b8898d1daa017b1553aa0272c", "0x79fcd87d09f7936b92eb68574156f188fedee9de961bd640fa47af9dc6c9a6ab", "0xb643b2d7e8368b64dedee4365e5c6df487df4cf12bd4bf7e941f2ef2104f14f3", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0xc7cddf9c1c0ef548f905fcf3251d79da5fd585a90636fb6ae3477cb3990e3db7" }
const proof41 = { nonce: 41n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xe7690fe5a6cb4eec8805284d0bd5faf554ae431693b82047d364e50a4d7833a5", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x8c81f75912eb6543ed84bd83f393f9e87742ec45a7bcd6455c9479fbeb24a222" }
const proof42 = { nonce: 42n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xc354422fe5b0707d805f80c2d89b4e8b109e9f34223069fb4eecd9af9ac8a861", "0xe7690fe5a6cb4eec8805284d0bd5faf554ae431693b82047d364e50a4d7833a5", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x2e96023b5c6162b804a16a692a55d381b6de4124abc139da3e78c4eab58e90f6" }
const proof43 = { nonce: 43n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xcab423a1104b2066c3aab0db276d22cb3d93485082aaab36ec44d7edb1606f94", "0xe7690fe5a6cb4eec8805284d0bd5faf554ae431693b82047d364e50a4d7833a5", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0xf299e8124efe463c2042e04ef8093fd2ac2b9b4f3c3f20c74a75cf8a512da8e6" }
const proof44 = { nonce: 44n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x5c3d895bcaa0764e79213169df8974674b12ad10dd03f7ca741c2ba915a11090", "0xcab423a1104b2066c3aab0db276d22cb3d93485082aaab36ec44d7edb1606f94", "0xe7690fe5a6cb4eec8805284d0bd5faf554ae431693b82047d364e50a4d7833a5", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x37c08cf147b044502cf6f2941655ada7c843bd81a72a41d57334aaeeb3e57be4" }
const proof45 = { nonce: 45n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x072815da579d300dc4256b08bae7e99c961e4addca247e7388003d7e0a88efee", "0xe7690fe5a6cb4eec8805284d0bd5faf554ae431693b82047d364e50a4d7833a5", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x1ea5ab8f78a31274fab5635279b92f77bf5d800bca7e8c1431683d8419bac0f5" }
const proof46 = { nonce: 46n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xbcc0bd2ab3664b89c566885aa9fe5f7cbe68b915d05b87e8cf9251c04cd7d795", "0x072815da579d300dc4256b08bae7e99c961e4addca247e7388003d7e0a88efee", "0xe7690fe5a6cb4eec8805284d0bd5faf554ae431693b82047d364e50a4d7833a5", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0xff254d82df08a0ccaf15b4505b346ebe779c68ac98874b76e03a0d40c100a14c" }
const proof47 = { nonce: 47n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xe7dba08f5ff96e085f863be592e6b72d3244104536eb185e84738552f839fd5b", "0x072815da579d300dc4256b08bae7e99c961e4addca247e7388003d7e0a88efee", "0xe7690fe5a6cb4eec8805284d0bd5faf554ae431693b82047d364e50a4d7833a5", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x3c6db0c223ef8a7d0c3331dcee049c99953f268d6be373e405c2dc8c3d3f2085" }
const proof48 = { nonce: 48n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xac5625b48d7366ff7ce984c6489b0ea4ebae6430b296e9574e326f01f0ae74f1", "0xe7dba08f5ff96e085f863be592e6b72d3244104536eb185e84738552f839fd5b", "0x072815da579d300dc4256b08bae7e99c961e4addca247e7388003d7e0a88efee", "0xe7690fe5a6cb4eec8805284d0bd5faf554ae431693b82047d364e50a4d7833a5", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x96b5ccb7840c15d7674269702b4a76fba57029f27e5549905ee6f860e91fd765" }
const proof49 = { nonce: 49n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xf48bf085e896c1b83e9bebe5c017ebf1a11f5bf0e10ea07f2c6e69ff15c79161", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x795fe7c98c2ccfdfa19e787392f4b0e38259de013903f1906dcfe2b7c3b80180" }
const proof50 = { nonce: 50n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0xafe613b8a75230c0b7865bb4cea1a48a592e4fda0609c4f5347cea3e6c867004", "0xf48bf085e896c1b83e9bebe5c017ebf1a11f5bf0e10ea07f2c6e69ff15c79161", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x02d5f48be66e52269cb31d17b5e8bfdf046512daa0a298e84bb8d46ee5607c0d" }
const proof51 = { nonce: 51n, to: "0xbcd4042de499d14e55001ccbb24a551f3b954096", amount: 100000000n, proof: ["0x9e210085cb72c34d3f98f333ef33ac87ab8f66c49b6088fe80b7b7d20d7c3843", "0xf48bf085e896c1b83e9bebe5c017ebf1a11f5bf0e10ea07f2c6e69ff15c79161", "0xdd2dd4bdb467a46c7ca94f6ac77ce8c490f1387b4fac3e6eac7d3f3cfb472e8f"], root: "0x0ff6abd23e0b398ee9d3426f27f11278a2f554791dd9150b73f66e51a69e1af0" }

describe("Bridge contract", function () {
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
    const bridgeContract = await ethers.deployContract("Bridge");
    await bridgeContract.waitForDeployment();
    return {
      bridgeContract,
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
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      expect(await bridgeContract.relayer()).to.equal(relayer.address);
    });

    it("Should have the right validators", async function () {
      const { bridgeContract, validator1, validator2, validator3, validator4, validator5, validator6, validator7 } = await loadFixture(deployBridgeFixture);
      expect(await bridgeContract.validators(0)).to.equal(validator1.address);
      expect(await bridgeContract.validators(1)).to.equal(validator2.address);
      expect(await bridgeContract.validators(2)).to.equal(validator3.address);
      expect(await bridgeContract.validators(3)).to.equal(validator4.address);
      expect(await bridgeContract.validators(4)).to.equal(validator5.address);
      expect(await bridgeContract.validators(5)).to.equal(validator6.address);
      expect(await bridgeContract.validators(6)).to.equal(validator7.address);
      await expect(bridgeContract.validators(7)).to.be.revertedWithoutReason();
    });
  });

  describe("Deposit", async function () {
    it("Deposit Proof #1", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      await fundContract(bridgeContract, relayer);

      const proofs = [proof1];
      const msgToSign = concatRoots(proofs);
      const signatures = await getValidatorSignatures(msgToSign);

      const tx = await bridgeContract.connect(relayer).deposit(proofs, signatures);
      await expect(tx).to.changeEtherBalances([bridgeContract, to1], [-toEthDecimals(proof1.amount), toEthDecimals(proof1.amount)]);
    });

    it("Deposit Proofs #1 & #2-#9", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      await fundContract(bridgeContract, relayer);
      const preproofs = [proof1];
      const premsgToSign = concatRoots(preproofs);
      const presignatures = await getValidatorSignatures(premsgToSign);
      await bridgeContract.connect(relayer).deposit(preproofs, presignatures);

      // Preparations done. Now deposit the rest of the proofs.

      const proofs = [proof2, proof3, proof4, proof5, proof6, proof7, proof8, proof9];
      const msgToSign = concatRoots(proofs);
      const signatures = await getValidatorSignatures(msgToSign, [2, 4, 5, 6, 7]);

      const tx = await bridgeContract.connect(relayer).deposit(proofs, signatures);

      const totalAmount = toEthDecimals(proof2.amount + proof3.amount + proof4.amount + proof5.amount + proof6.amount + proof7.amount + proof8.amount + proof9.amount);
      await expect(tx).to.changeEtherBalances([bridgeContract, to2, to3, to4, to5, to6, to7, to8, to9],
        [-totalAmount,
        toEthDecimals(proof2.amount),
        toEthDecimals(proof3.amount),
        toEthDecimals(proof4.amount),
        toEthDecimals(proof5.amount),
        toEthDecimals(proof6.amount),
        toEthDecimals(proof7.amount),
        toEthDecimals(proof8.amount),
        toEthDecimals(proof9.amount)]);
    });

    it("Should revert with empty proofs", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      await expect(bridgeContract.connect(relayer).deposit([], [])).to.be.revertedWith("At least 1 proof is required.");
    });

    it("Should revert with proofs length greater than 10", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      const proofs = [proof1, proof2, proof3, proof4, proof5, proof6, proof7, proof8, proof9, proof10, proof11];
      await expect(bridgeContract.connect(relayer).deposit(proofs, [])).to.be.revertedWith("At most 10 proofs are allowed.");
    });

    it("Should revert with the wrong first nonce", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      await expect(bridgeContract.connect(relayer).deposit([proof2], [])).to.be.revertedWith("Only the next nonce is allowed in the first proof.");
    });

    it("Should revert when nonce is not subsequent", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      await expect(bridgeContract.connect(relayer).deposit([proof1, proof3], [])).to.be.revertedWith("The nonces of the proofs must be subsequent.");
    });

    it("Should revert when signature length is not 5", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      const proofs = [proof1, proof2];
      const msgToSign = concatRoots(proofs);
      const signatures = await getValidatorSignatures(msgToSign, [2, 4, 5, 6]);

      await expect(bridgeContract.connect(relayer).deposit(proofs, signatures)).to.be.revertedWith("Distribution requires exactly 5 signatures of the 7 validators.");
    });

    it("Should revert when signature verify failed", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      const proofs = [proof1, proof2];
      const msgToSign = concatRoots(proofs);
      const signatures = await getValidatorSignatures(msgToSign, [0, 2, 4, 5, 6]);
      await expect(bridgeContract.connect(relayer).deposit(proofs, signatures)).to.be.revertedWith("Validator signature verification failed.");
    });

    it("Should continue when contract fund is insufficient", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      const amount = ethers.parseEther("1.0");
      const to = await bridgeContract.getAddress()
      await relayer.sendTransaction({ to, value: amount });

      const proofs = [proof1, proof2];
      const msgToSign = concatRoots(proofs);
      const signatures = await getValidatorSignatures(msgToSign);
      // Depends on What happens if the transfer fails?
      const tx = await bridgeContract.connect(relayer).deposit(proofs, signatures);
      await expect(tx).to.changeEtherBalances([bridgeContract, to1, to2], [-toEthDecimals(proof1.amount), toEthDecimals(proof1.amount), 0]);
      // await expect(bridgeContract.connect(relayer).deposit(proofs,signatures)).to.be.revertedWithPanic(0x1);
    });

    it("Should revert when any one proof verify failed", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      fundContract(bridgeContract, relayer);

      let invalidproof = proof2;
      invalidproof.proof = [ethers.sha256(ethers.ZeroHash)];
      const proofs = [proof1, invalidproof];
      const msgToSign = concatRoots(proofs);
      const signatures = await getValidatorSignatures(msgToSign);
      await expect(bridgeContract.connect(relayer).deposit(proofs, signatures)).to.be.revertedWithoutReason();
    });

    it("Should do nothing when one of the recipient is contract address", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
      fundContract(bridgeContract, relayer);

      const bridgeContractAddress = await bridgeContract.getAddress();
      const { proof, root } = await createMerkleTree(2, bridgeContractAddress, ethers.parseEther("1"));
      const self_createproof = { nonce: 2, to: bridgeContractAddress, amount: ethers.parseEther("1"), proof: proof, root: root };
      const proofs = [proof1, self_createproof];
      const msgToSign = concatRoots(proofs);
      const signatures = await getValidatorSignatures(msgToSign);
      const tx = await bridgeContract.connect(relayer).deposit(proofs, signatures);
      await expect(tx).to.changeEtherBalances([bridgeContract, proof1.to], [-toEthDecimals(proof1.amount), toEthDecimals(proof1.amount)]);
    });

  });
});
