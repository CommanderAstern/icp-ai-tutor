const fs = require('fs');
const { AssetManager } = require('@dfinity/assets');
const { HttpAgent } = require('@dfinity/agent');
const { Principal } = require('@dfinity/principal');

// Configuration
const canisterId = Principal.fromText('bw4dl-smaaa-aaaaa-qaacq-cai');
const identity = /* Your identity setup here */;
const filePath = '../../ml/chroma_store.zip'; // The file you want to upload

async function main() {
    const agent = new HttpAgent({ identity });
    
    // Ensure the agent is ready (fetches root key for localhost only)
    await agent.fetchRootKey();

    const assetManager = new AssetManager({
        canisterId: canisterId,
        agent: agent,
    });

    try {
        const file = fs.readFileSync(filePath);
        const fileName = filePath.split('/').pop(); // Extract file name from path

        const key = await assetManager.store(file, {fileName: fileName});
        console.log(`File uploaded successfully. Key: ${key}`);
    } catch (error) {
        console.error("Error uploading file:", error);
    }
}

main();
