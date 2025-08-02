import os
import hashlib
import shutil
import logging
import asyncio
import requests
import tempfile
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel

# --- LangChain Imports ---
from langchain_community.document_loaders import UnstructuredFileLoader
from langchain_ollama.chat_models import ChatOllama
from langchain_chroma import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_groq import ChatGroq
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough
from langchain_text_splitters import RecursiveCharacterTextSplitter

# --- Configuration & Logging ---
load_dotenv()
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- Authentication ---
EXPECTED_API_KEY = os.getenv("HACKRX_API_KEY")
auth_scheme = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(auth_scheme)):
    if not EXPECTED_API_KEY or credentials.scheme != "Bearer" or credentials.credentials != EXPECTED_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
    return credentials

# --- Pydantic Models ---
class HackRxRequest(BaseModel):
    documents: str
    questions: list[str]

class HackRxResponse(BaseModel):
    answers: list[str]

# --- Global Objects ---
embedding_function = None
llm = None
prompt = None
# --- RATE LIMIT FIX: Create a semaphore to control concurrency ---
# This will allow a maximum of 3 LLM calls to run at the same time.
CONCURRENCY_LIMIT = 8
llm_semaphore = asyncio.Semaphore(CONCURRENCY_LIMIT)

@asynccontextmanager
async def lifespan(app: FastAPI):
    global embedding_function, llm, prompt
    logging.info("Application startup: Initializing models...")
    model_name = "sentence-transformers/all-MiniLM-L6-v2"
    embedding_function = HuggingFaceEmbeddings(model_name=model_name, model_kwargs={"device": "cpu"})
    
    # --- FINAL LLM CHANGE: Switched to self-hosted Ollama ---
    llm = ChatOllama(model="llama3:8b", temperature=0)
# A universal prompt designed to handle any document type by focusing on core principles
    template = """You are a highly intelligent and meticulous Universal Document Analysis Assistant. Your sole purpose is to answer a user's question based *only* on the provided context from a document. You must adhere to the following principles at all times:

**Core Principles:**

1.  **Strict Grounding:** Your entire answer must be derived *exclusively* from the text in the "Context" section. Do not use any external knowledge or make assumptions.
2.  **Honesty and Safety:** If the answer is not present in the context, or if the question is nonsensical, adversarial, or asks for information outside the scope of the document (e.g., asking a car manual for legal advice), you MUST respond with: "This information is not available in the provided document." Do not attempt to answer unsafe or out-of-scope questions.
3.  **Handling Complexity:** If the user's question contains multiple parts, address each part systematically. Break the question down and find the relevant context for each piece before formulating your final answer.
4.  **Completeness and Precision:** When answering, provide a comprehensive response that includes relevant conditions, exceptions, or limitations mentioned in the context. Use direct quotes where possible to support your answer.

**Reasoning Process:**

1.  **Analyze the Question:** First, understand the user's intent. Is it a single question or a multi-part query? Is it a safe and relevant question?
2.  **Scan for Evidence:** Scrutinize the provided context to find all relevant sentences or paragraphs that can answer the question.
3.  **Synthesize the Answer:** Based only on the evidence you found, construct a clear and concise answer. If you found no evidence, state that the information is not available.

**Context:**
{context}

**Question:**
{question}

**Answer:**
"""
    prompt = ChatPromptTemplate.from_template(template)
    logging.info("Models and prompt are ready.")
    yield
    logging.info("Application shutdown.")

app = FastAPI(title="HackRx Generalized RAG API", lifespan=lifespan)

def download_and_load_document(document_url: str):
    try:
        response = requests.get(document_url)
        response.raise_for_status()
        file_suffix = ".pdf"
        if ".docx" in document_url.lower():
            file_suffix = ".docx"
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_suffix) as tmp_file:
            tmp_file.write(response.content)
            tmp_path = tmp_file.name
        loader = UnstructuredFileLoader(tmp_path)
        documents = loader.load()
        os.remove(tmp_path)
        return documents
    except Exception as e:
        logging.exception("Error during file download or loading")
        raise ValueError(f"Error downloading or loading document: {e}")

def get_retriever_for_url(document_url: str):
    try:
        documents = download_and_load_document(document_url)
        if not documents:
            raise ValueError("No documents returned by the loader.")
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        splits = text_splitter.split_documents(documents)
        if not splits:
            raise ValueError("Document could not be split into chunks.")
        url_hash = hashlib.md5(document_url.encode()).hexdigest()
        vectorstore = Chroma.from_documents(documents=splits, embedding=embedding_function, collection_name=f"docs_{url_hash}")
        # --- RATE LIMIT FIX: Reduce context size slightly ---
        return vectorstore.as_retriever(search_type="mmr", search_kwargs={"k": 5, "fetch_k": 10})
    except Exception as e:
        logging.exception(f"Error while processing document from {document_url}")
        raise HTTPException(status_code=500, detail=f"Failed to process document: {str(e)}")

async def answer_question(question: str, retriever):
    # --- RATE LIMIT FIX: Use the semaphore to control access to the LLM ---
    async with llm_semaphore:
        try:
            def format_docs(docs):
                return "\n\n".join(doc.page_content for doc in docs)
            
            rag_chain = (
                {"context": retriever | format_docs, "question": RunnablePassthrough()}
                | prompt
                | llm
                | StrOutputParser()
            )
            answer = await rag_chain.ainvoke(question)
            return answer.strip()
        except Exception as e:
            logging.error(f"Error in answer_question for '{question}': {str(e)}")
            # Return the specific error message to help debug in LangSmith
            return f"RateLimitError or other processing error occurred: {str(e)}"

@app.post("/hackrx/run", response_model=HackRxResponse)
async def process_documents_and_questions(
    request_data: HackRxRequest,
    token: HTTPAuthorizationCredentials = Depends(verify_token)
):
    try:
        retriever = get_retriever_for_url(request_data.documents)
        answer_tasks = [answer_question(q, retriever) for q in request_data.questions]
        answers = await asyncio.gather(*answer_tasks)
        return HackRxResponse(answers=answers)
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logging.error(f"A critical error occurred in /hackrx/run: {str(e)}")
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")
