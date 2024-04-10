import os
import requests
import shutil
import zipfile
from flask import Flask, request, jsonify
from langchain.vectorstores import Chroma
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.chains import load_qa_chain
from langchain.chat_models import ChatOpenAI

app = Flask(__name__)

@app.route('/query', methods=['GET'])
def query_endpoint():
    query = request.json['query']
    temp_folder = f"temp_storage_{request.remote_addr}"
    zip_path = f"./{temp_folder}/chroma_store_1_pdf.zip"
    db_path = f"./{temp_folder}/chroma_store_1"
    url = "http://ajuq4-ruaaa-aaaaa-qaaga-cai.localhost:4943/chroma_store_1_pdf.zip"

    try:
        os.makedirs(temp_folder, exist_ok=True)
        response = requests.get(url)
        if response.status_code == 200:
            with open(zip_path, 'wb') as f:
                f.write(response.content)
            message = "File downloaded successfully."
        else:
            message = f"Failed to download the file. Status code: {response.status_code}"
            return jsonify({'error': message}), 500

        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(db_path)
        print(message)

        db = Chroma(persist_directory=db_path, embedding_function=OpenAIEmbeddings())
        model_name = "gpt-3.5-turbo"
        llm = ChatOpenAI(model_name=model_name)
        chain = load_qa_chain(llm, chain_type="stuff")
        matching_docs = db.similarity_search(query)
        answer = chain.run(input_documents=matching_docs, question=query)

        db.close()  # Close the Chroma database connection

        return jsonify({'answer': answer})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        shutil.rmtree(temp_folder)

if __name__ == '__main__':
    app.run()