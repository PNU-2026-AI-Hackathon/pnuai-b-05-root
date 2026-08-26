"""LangChain RAG 기반 무화과 재배 챗봇 파이프라인.

농촌진흥청 무화과 재배 매뉴얼을 참고해 정리한 지식 문서를 코드에 직접
하드코딩하고(PDF 등 외부 파일 의존 없음) ChromaDB로 벡터화해 저장한다.
질의 시 관련 문서를 검색(retrieval)한 뒤 Gemini API로 답변을 생성한다.
"""
import os

from django.conf import settings
from langchain_classic.chains import RetrievalQA
from langchain_community.vectorstores import Chroma
from langchain_core.documents import Document
from langchain_core.prompts import PromptTemplate
from langchain_google_genai import ChatGoogleGenerativeAI, GoogleGenerativeAIEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter

PERSIST_DIRECTORY = os.path.join(os.path.dirname(__file__), 'vector_store')

EMBEDDING_MODEL = 'models/gemini-embedding-001'
LLM_MODEL = 'gemini-2.5-flash'
# gemini-2.5-flash는 기본으로 thinking이 켜져 있어 응답이 5~8초가량 걸린다.
# 10초는 배포 환경(느린 컨테이너 + Google 왕복 지연)에서 종종 타임아웃 폴백을
# 유발할 만큼 빠듯해 20초로 잡는다. gunicorn 자체 타임아웃(120초)이 최종 상한.
LLM_TIMEOUT_SECONDS = 20
RETRIEVAL_K = 3
CHUNK_SIZE = 300
CHUNK_OVERLAP = 30

# RAG 답변 생성용 커스텀 프롬프트.
# RetrievalQA의 LangChain 기본 프롬프트는 "문서에 근거가 없으면 모른다고 답하라"는
# 지시라, 매뉴얼(KNOWLEDGE_DOCUMENTS) 밖의 질문을 지나치게 딱딱하게 거부한다.
# 프론트 UI의 '무화과 박사 피그' 캐릭터와 톤을 맞추고, 참고 자료가 없어도 일반
# 재배 지식으로 답하되 단정하지 않도록 답변 태도를 직접 지정한다.
ANSWER_PROMPT = PromptTemplate(
    input_variables=['context', 'question'],
    template=(
        '당신은 무화과 재배를 도와주는 친근한 AI 챗봇 "무화과 박사 피그"입니다. '
        '무화과를 사랑하는 다정하고 편안한 말투로, 존댓말로 답합니다.\n\n'
        '아래는 농촌진흥청 무화과 재배 매뉴얼에서 질문과 관련해 찾은 참고 자료입니다.\n'
        '----------\n'
        '{context}\n'
        '----------\n\n'
        '답변 규칙:\n'
        '1. 참고 자료가 질문과 관련이 있으면, 그 내용을 우선 근거로 삼아 답합니다.\n'
        '2. 참고 자료에 없는 질문이라도 절대 "정보가 없다"며 거부하지 말고, '
        '일반적인 식물·원예 재배 지식으로 최대한 도움이 되게 답합니다.\n'
        '3. 참고 자료에 없거나 확실하지 않은 내용을 말할 때는 단정하지 말고 '
        '"일반적으로는", "정확한 건 상황에 따라 조금씩 달라요"처럼 여지를 두는 표현을 씁니다.\n'
        '4. 무화과와 전혀 관계없는 질문이면 짧게만 답한 뒤 자연스럽게 무화과 이야기로 돌아오도록 안내합니다.\n'
        '5. 항상 한국어로, 2~4문장 정도로 간결하게 답합니다.\n\n'
        '질문: {question}\n\n'
        '무화과 박사 피그의 답변:'
    ),
)

# 농촌진흥청 무화과 재배 매뉴얼 기반 지식 문서 (하드코딩)
KNOWLEDGE_DOCUMENTS = [
    '무화과의 생육 적정 온도는 13~28℃이며, 20~25℃ 구간에서 가장 왕성하게 자란다. '
    '10℃ 이하로 떨어지면 생육이 정지되고, 30℃를 넘으면 잎이 시들거나 열매가 조기 낙과할 '
    '수 있어 여름철에는 환기와 차광에 신경 써야 한다.',

    '무화과 재배 적정 습도는 60~80%이다. 습도가 50% 미만으로 낮아지면 잎끝이 마르는 '
    '증상이 나타나고, 80%를 초과하는 다습 환경이 지속되면 곰팡이성 병해 발생 위험이 '
    '커지므로 적정 범위를 유지하는 것이 중요하다.',

    '무화과는 광보상점이 낮은 편이라 음지에서도 비교적 잘 견디는 작물이다. 다만 광량이 '
    '지나치게 부족하면 가지가 웃자라고 열매 당도가 떨어지므로, 실내 재배 시에도 최소한의 '
    '산광(散光) 조건은 확보해주는 것이 좋다.',

    '수분이 부족하면 잎이 아래로 처지고 가장자리부터 갈변하며 마르는 증상이 나타난다. '
    '이런 증상이 보이면 즉시 관수량을 늘리고, 화분 배수구 아래 물받이에 물이 고여 있지 '
    '않은지 함께 확인해 뿌리 손상 여부를 점검한다.',

    '과습 상태가 지속되면 뿌리가 검게 변하며 무르는 뿌리썩음 증상이 나타나고, 잎이 '
    '누렇게 변하며 떨어질 수 있다. 관수 간격을 늘리고 배수가 잘 되는 상토로 교체하며, '
    '심한 경우 화분에서 꺼내 상한 뿌리를 제거한 뒤 다시 심어야 한다.',

    '무화과는 삽목으로 번식하며, 통상 15~20cm 길이의 가지를 잘라 상토에 꽂은 뒤 '
    '반그늘에서 관리한다. 발근까지는 대략 3~4주가 소요되며, 이 기간에는 흙이 마르지 '
    '않도록 꾸준히 수분을 공급해야 한다.',

    '삽목 후 뿌리가 안정적으로 활착하고 새 가지와 잎이 왕성하게 자라 이식이 가능한 '
    '크기(초장 30cm 이상)에 도달하기까지는 약 3개월이 소요되며, 이 시점을 묘목 완성 '
    '기준으로 본다.',

    '무화과에 흔한 병해로는 잿빛곰팡이병, 녹병이 있고 해충으로는 하늘소, 깍지벌레가 '
    '있다. 예방을 위해 통풍을 확보하고 병든 잎과 가지는 즉시 제거하며, 발생 초기에는 '
    '적용 약제를 희석해 살포한다.',

    '생육기(4~9월)에는 2~3주 간격으로 질소·인산·칼륨이 균형 잡힌 액체비료를 희석해 '
    '공급하고, 휴면기인 겨울철에는 시비를 중단한다. 과도한 질소 비료는 열매보다 잎과 '
    '가지만 무성해지는 웃자람을 유발하므로 주의한다.',

    '실내에서 재배할 때는 자연광이 부족할 수 있어 식물생장용 LED를 하루 10~12시간, '
    '화분에서 30~50cm 거리를 두고 조사해 광량을 보충한다. 백색광과 적색광이 혼합된 '
    '풀스펙트럼 LED가 생육에 효과적이다.',
]


def _build_embeddings():
    return GoogleGenerativeAIEmbeddings(
        model=EMBEDDING_MODEL,
        google_api_key=settings.GEMINI_API_KEY,
    )


def _build_chunks():
    documents = [Document(page_content=text) for text in KNOWLEDGE_DOCUMENTS]
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE, chunk_overlap=CHUNK_OVERLAP,
    )
    return splitter.split_documents(documents)


def initialize_rag():
    """지식 문서를 임베딩해 ChromaDB 벡터스토어를 구축(또는 기존 저장소를 로드)한다.

    `PERSIST_DIRECTORY`에 이미 벡터스토어가 저장되어 있으면 재임베딩 없이
    그대로 로드하고, 없으면 새로 구축해 저장한다.

    Returns:
        Chroma: 검색 가능한 벡터스토어 인스턴스
    """
    embeddings = _build_embeddings()

    if os.path.isdir(PERSIST_DIRECTORY) and os.listdir(PERSIST_DIRECTORY):
        return Chroma(persist_directory=PERSIST_DIRECTORY, embedding_function=embeddings)

    return Chroma.from_documents(
        _build_chunks(), embedding=embeddings, persist_directory=PERSIST_DIRECTORY,
    )


def ask_question(question, vectorstore):
    """벡터스토어에서 관련 문서를 검색해 Gemini로 답변을 생성한다.

    Args:
        question: 사용자 질문
        vectorstore: `initialize_rag()`로 생성한 벡터스토어

    Returns:
        str: 생성된 답변
    """
    llm = ChatGoogleGenerativeAI(
        model=LLM_MODEL, google_api_key=settings.GEMINI_API_KEY, timeout=LLM_TIMEOUT_SECONDS,
    )
    qa_chain = RetrievalQA.from_chain_type(
        llm=llm,
        retriever=vectorstore.as_retriever(search_kwargs={'k': RETRIEVAL_K}),
        chain_type_kwargs={'prompt': ANSWER_PROMPT},
    )
    result = qa_chain.invoke({'query': question})
    return result['result']
