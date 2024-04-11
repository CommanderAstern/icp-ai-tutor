import os
import requests
import zipfile
from flask import Flask, request, jsonify
from langchain_community.vectorstores import Chroma
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.chains.question_answering import load_qa_chain
from langchain.chat_models import ChatOpenAI
from dotenv import load_dotenv
import random 
import re
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

load_dotenv()
app = Flask(__name__)

# Dictionary to hold the initialized Chroma stores
chroma_stores = {}
random.seed(42)

query_cache = {}
generate_question_cache = {}

def initialize_chroma_stores():
    """Initialize all Chroma stores and store them in the chroma_stores dictionary."""
    for store_id in range(5):  # Assuming 5 stores
        temp_folder = f"chroma_store_{store_id}"
        zip_path = f"./{temp_folder}/chroma_store_{store_id}_pdf.zip"
        db_path = f"./{temp_folder}"

        # Download and extract the Chroma store data
        # Using the same URL for all stores as a placeholder
        url = "https://hwtwo-6aaaa-aaaal-qiyta-cai.icp0.io/"+f"chroma_store_{store_id+1}_pdf.zip"
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

@app.route('/query', methods=['GET', 'POST'])
def query_endpoint():
    data = request.json
    query = data['query']
    store_id = data.get('store_id', 0)

    if query+str(store_id) in query_cache:
        print(jsonify(query_cache[query+str(store_id)]))
        return jsonify(query_cache[query+str(store_id)])

    

    if store_id < 0 or store_id > 4:
        return jsonify({'error': 'store_id must be between 1 and 5'}), 400

    # Select the Chroma store based on store_id
    db = chroma_stores.get(store_id)
    if not db:
        return jsonify({'error': 'Chroma store not initialized'}), 500

    model_name = "gpt-3.5-turbo"
    llm = ChatOpenAI(model_name=model_name, temperature=0, model_kwargs={"seed": 42})
    chain = load_qa_chain(llm, chain_type="stuff")
    matching_docs = db.similarity_search(query)
    answer = chain.run(input_documents=matching_docs, question=query)
    response = {'answer': answer}
    query_cache[query+str(store_id)] = response
    print(response)
    return jsonify(response)

@app.route('/generate_question', methods=['GET', 'POST'])
def generate_question_endpoint():
    data = request.json
    query = data['query']
    store_id = data.get('store_id', 0)

    if query+str(store_id) in generate_question_cache:
        return jsonify(generate_question_cache[query+str(store_id)])


    if store_id < 0 or store_id > 4:
        return jsonify({'error': 'store_id must be between 0 and 4'}), 400

    db = chroma_stores.get(store_id)
    if not db:
        return jsonify({'error': 'Chroma store not initialized'}), 500

    llm = ChatOpenAI(model_name="gpt-3.5-turbo", temperature=0)

    # Assuming `load_qa_chain()` is a defined function that loads the QA chain
    chain = load_qa_chain(llm, chain_type="stuff")
    
    content_query = (f"Give content from the documents provided for the following query. If the query doesn't make sense "
                     f"or doesn't relate to the document provided give a general overview of the pdf. Make sure the content "
                     f"is of at least 300 words: {query}")
    
    matching_docs = db.similarity_search(content_query)
    answer = chain.run(input_documents=matching_docs, question=content_query)
    
    question_prompt = ChatPromptTemplate.from_messages([
        ("system", "You are a world-class quiz writer who creates questions and answers from content."),
        ("user", "{input}")
    ])
    question_chain = question_prompt | llm | StrOutputParser()
    question_res = question_chain.invoke({
        "input": f"From the given context: {answer}. Make 3 Questions."+ "The question should be in this format #questionstart#{question-content}#questionend# for each question. For a total of 3 times."
    })
    
    question_pattern = r"#questionstart#(.*?)#questionend#"
    questions = re.findall(question_pattern, question_res)

    
    answer_prompt = ChatPromptTemplate.from_messages([
        ("system", "You are a world-class quiz writer who creates one correct and three incorrect answers for quiz questions."),
        ("user", "{input}")
    ])
    answer_chain = answer_prompt | llm | StrOutputParser()
    
    placeholder = "Placeholder"
    quiz_results = []
    
    for question in questions:
        res = answer_chain.invoke({
            "input": f"Based on the question: {question}. Generate one correct answer and three incorrect answers for a quiz. "
                     "Format the answers as follows: #correctanswer#Correct Answer#end# "
                     "and #wronganswer#Wrong Answer 1#end# #wronganswer#Wrong Answer 2#end# #wronganswer#Wrong Answer 3#end#."
        })
        
        correct_pattern = r"#correctanswer#(.*?)#end#"
        wrong_pattern = r"#wronganswer#(.*?)#end#"
        
        correct_answer = re.findall(correct_pattern, res)
        incorrect_answers = re.findall(wrong_pattern, res)
        
        # Remove "Wrong Answer" and "Correct Answer" text from the answers
        correct_answer = [answer.replace("Correct Answer", "").strip() for answer in correct_answer]
        incorrect_answers = [answer.replace("Wrong Answer", "").strip() for answer in incorrect_answers]
        
        if not correct_answer or len(incorrect_answers) < 3:
            correct_answer = [placeholder]
            incorrect_answers = [placeholder for _ in range(3)]

        answers = correct_answer + incorrect_answers[:3]
        random.shuffle(answers)
        correct_index = answers.index(correct_answer[0])

        # Clean the question if necessary
        question = question if question and question.strip() != "#questionstart##questionend#" else placeholder

        quiz_results.append({
            "question": question,
            "answers": answers,
            "correct_index": correct_index
        })
    generate_question_cache[query+str(store_id)] = quiz_results
    return jsonify(quiz_results)


if __name__ == '__main__':
    initialize_chroma_stores()
    app.run(debug=True, port=8000, threaded=False)
