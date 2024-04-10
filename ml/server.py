import os
import requests
import shutil
import zipfile
from flask import Flask, request, jsonify
from langchain_community.vectorstores import Chroma
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.chains.question_answering import load_qa_chain
from langchain.chat_models import ChatOpenAI
from dotenv import load_dotenv
import pickle

load_dotenv()
app = Flask(__name__)

# Dictionary to hold the initialized Chroma stores
chroma_stores = {}

def initialize_chroma_stores():
    """Initialize all Chroma stores and store them in the chroma_stores dictionary."""
    for store_id in range(5):  # Assuming 5 stores
        temp_folder = f"chroma_store_{store_id}"
        zip_path = f"./{temp_folder}/chroma_store_{store_id}_pdf.zip"
        db_path = f"./{temp_folder}"

        # Download and extract the Chroma store data
        # Using the same URL for all stores as a placeholder
        url = "http://ajuq4-ruaaa-aaaaa-qaaga-cai.localhost:4943/chroma_store_1_pdf.zip"
        os.makedirs(temp_folder, exist_ok=True)
        response = requests.get(url)
        if response.status_code == 200:
            with open(zip_path, 'wb') as f:
                f.write(response.content)
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(db_path)
            print(f"Chroma store {store_id} initialized.")
        else:
            print(f"Failed to initialize Chroma store {store_id}. Status code: {response.status_code}")
            continue
        
        # Initialize and store the Chroma object
        db = Chroma(persist_directory=db_path+'/chroma_store', embedding_function=OpenAIEmbeddings())
        chroma_stores[store_id] = db

@app.route('/query', methods=['GET'])
def query_endpoint():
    data = request.json
    query = data['query']
    store_id = data.get('store_id', 0)
    
    if store_id < 0 or store_id > 4:
        return jsonify({'error': 'store_id must be between 1 and 5'}), 400

    # Select the Chroma store based on store_id
    db = chroma_stores.get(store_id)
    if not db:
        return jsonify({'error': 'Chroma store not initialized'}), 500

    model_name = "gpt-3.5-turbo"
    llm = ChatOpenAI(model_name=model_name)
    chain = load_qa_chain(llm, chain_type="stuff")
    matching_docs = db.similarity_search(query)
    answer = chain.run(input_documents=matching_docs, question=query)

    return jsonify({'answer': answer})

if __name__ == '__main__':
    initialize_chroma_stores()
    app.run(debug=True, port=8000)