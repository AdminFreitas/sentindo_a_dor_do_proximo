import time
from collections import defaultdict

from app.config import settings

"""
Rate limiting de login (regra 14 de SDP_SEGURANCA.md).

ATENCAO: implementacao em memoria do processo - funciona para um unico worker/
instancia. Antes de rodar mais de uma instancia do backend em producao (T08 em
SDP_DECISOES_PENDENTES.md trata observabilidade; isso e infraestrutura correlata),
trocar por um contador compartilhado (Redis) - senao cada instancia conta
tentativas separadamente e o limite real fica maior que o configurado.
"""

_tentativas: dict[str, list[float]] = defaultdict(list)


def _chave(identificador: str) -> str:
    # identificador = email + IP, para nao bloquear todo mundo atras do mesmo IP
    # por causa de uma unica conta sob ataque, nem permitir bypass so trocando de IP.
    return identificador


def registrar_tentativa_falha(email: str, ip: str) -> None:
    chave = _chave(f"{email}:{ip}")
    agora = time.time()
    _tentativas[chave] = [t for t in _tentativas[chave] if agora - t < settings.login_janela_segundos]
    _tentativas[chave].append(agora)


def limite_excedido(email: str, ip: str) -> bool:
    chave = _chave(f"{email}:{ip}")
    agora = time.time()
    tentativas_recentes = [t for t in _tentativas[chave] if agora - t < settings.login_janela_segundos]
    _tentativas[chave] = tentativas_recentes
    return len(tentativas_recentes) >= settings.login_max_tentativas


def limpar_tentativas(email: str, ip: str) -> None:
    """Chamado apos login bem-sucedido."""
    _tentativas.pop(_chave(f"{email}:{ip}"), None)
