import fs from 'fs';
import { AssetManager } from '@dfinity/assets';
import { HttpAgent } from '@dfinity/agent';
import { Principal } from '@dfinity/principal';
import { Ed25519KeyIdentity   } from '@dfinity/identity';
import canisterIds from '../../.dfx/local/canister_ids.json' assert { type: 'json' };
import path from 'path';
import { fileURLToPath } from 'url';

// const HOST = `http://localhost:4943`;
// const frontendCanisterId = canisterIds['ai-tutor-backend'].local;
// console.log(frontendCanisterId);
// const canisterId = Principal.fromText(frontendCanisterId);
const identity = Ed25519KeyIdentity.generate(new Uint8Array(Array.from({length: 32}).fill(0)));

console.log(identity.getPrincipal());

const filePath = 'chroma_store_1_pdf.zip';
const HOST = `http://127.0.0.1:4943`;
const canisterId = "ajuq4-ruaaa-aaaaa-qaaga-cai"

async function main() {
    const agent = new HttpAgent({ host: HOST, identity });
    
    // Ensure the agent is ready (fetches root key for localhost only)
    await agent.fetchRootKey();
    // console.log(agent)
    const assetManager = new AssetManager({
        canisterId: canisterId,
        agent: agent,
    });

    console.log(assetManager);

    try {
        const file = fs.readFileSync(filePath);
        const fileName = "chroma_store_1_pdf.zip"

        const key = await assetManager.store(file, {fileName: fileName});
        console.log(`File uploaded successfully. Key: ${key}`);
    } catch (error) {
        console.error("Error uploading file:", error);
    }
}

main();
