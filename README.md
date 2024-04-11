# AI Personal Tutor on the Internet Computer

![GitHub last commit](https://img.shields.io/github/last-commit/CommanderAstern/icp-ai-tutor)
![Issues](https://img.shields.io/github/issues/CommanderAstern/icp-ai-tutor)
![Pull Requests](https://img.shields.io/github/issues-pr/CommanderAstern/icp-ai-tutor)
![License](https://img.shields.io/github/license/CommanderAstern/icp-ai-tutor)
![Forks](https://img.shields.io/github/forks/CommanderAstern/icp-ai-tutor?style=social)
![Stars](https://img.shields.io/github/stars/CommanderAstern/icp-ai-tutor?style=social)

AI Personal Tutor leverages the power of the Internet Computer Protocol (ICP) to offer a decentralized, blockchain-based learning platform. This innovative solution aims to provide personalized tutoring and learning management for students, while also equipping teachers with tools to monitor progress, set assignments, and interact with their classes.

## Features

- **AI-Driven Tutoring**: Personalized learning experiences tailored to each student's needs.
- **Teacher Dashboard**: Comprehensive tools for managing content, tracking student progress, and communicating with students.
- **Student Dashboard**: A user-friendly interface for accessing course materials, viewing progress, and taking quizzes.
- **Secure and Scalable**: Built on the ICP blockchain, ensuring security, scalability, and data integrity.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

List all the software:
- DFX SDK
- Motoko Package Manager
- Node.js

### Installing
#### Creating Vectore Store
1. Go to the `ml` directory
```bash
cd ml
```
2. Create a new virtual environment
```bash
python3 -m venv venv
```
3. Activate the virtual environment
```bash
source venv/bin/activate
```
4. Install the required packages
```bash
pip install -r requirements.txt
```
5. Add the pdf files to the `pdfs` directoryq
6. run the codeblock in `experiments.ipynb` to create the vector store
7. Zip the `chroma_store` directory
8. Run `../src/scripts/uploadAsset.js` to upload the zip file to the internet computer
#### Motoko and Svelte
1. Install Motoko packages
```bash
mops install
```
2. Configure the backend server URL in the `src/ai-tutor-backend/main.mo` file
3. Build the project
```bash
dfx build
```
4. Deploy the project
```bash
dfx deploy
```
#### Backend Server
1. go to ml directory
```bash
cd ml
```
2. Update the container url in `app.py` file
2. Start flask server
```bash
python3 app.py
```



## Built With

* [Internet Computer Protocol (ICP)](https://dfinity.org/) - The blockchain framework used
* [Svelte](https://svelte.dev/) - The web framework used
* [Node.js](https://nodejs.org/) - Server Environment