# Sentindo a Dor do Próximo — Backend

Módulo de autenticação (login/logout/sessão) implementado conforme:
- `SDP_DOCUMENTACAO_PROJETO.md` — seções 3.5 (estratégia de autenticação) e 6.2 (schema).
- `SDP_SEGURANCA.md` — regras 3, 4, 5, 10, 14, 18.
- `SDP_API.md` — contrato de `/api/auth/login` e `/api/auth/logout`.
- `SDP_DECISOES_PENDENTES.md` — T01 (FastAPI) e T02 (sessão via servidor) aprovadas.

## O que já está implementado

- `POST /api/auth/login` — valida credenciais, cria sessão no banco, devolve cookie `HttpOnly/Secure/SameSite=Strict`.
- `POST /api/auth/logout` — revoga a sessão de fato no servidor (não só apaga o cookie no cliente).
- `GET /api/auth/me` — endpoint de apoio para conferir a sessão manualmente.
- `GET /health` — health check básico (sem autenticação).
- Hash de senha com Argon2id.
- Rate limiting de tentativas de login (em memória — ver aviso em `app/auth/rate_limit.py` sobre produção com múltiplas instâncias).
- Auditoria de `LOGIN`, `LOGIN_FALHOU` e `LOGOUT`.
- `exigir_papel(...)` em `app/auth/dependencies.py` — pronto para os próximos módulos (pessoas, serviços etc.) aplicarem RBAC.
- 8 testes automatizados cobrindo login correto/incorreto, usuário inexistente, rate limit, `/me` autenticado/não autenticado e logout — **todos passando** (`pytest`).

## O que **não** está implementado ainda (propositalmente)

- Migrations com Alembic — hoje o bootstrap usa `Base.metadata.create_all` (atalho de dev). Trocar antes de existir dado real em produção (T09, ainda pendente de aprovação).
- Separação real dos usuários do PostgreSQL por privilégio (T04) — o `docker-compose.yml` sobe só o usuário dono; falta o script que cria o `app_runtime` com privilégios restritos.
- Qualquer módulo além de autenticação (pessoas, serviços, elegibilidade etc.).

## Como rodar localmente

```bash
# 1. Ambiente virtual
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 2. Dependências
pip install -r requirements.txt

# 3. Variáveis de ambiente
cp .env.example .env
# edite .env se necessário (senha do banco, etc.)

# 4. Banco de dados (Postgres via Docker)
docker compose up -d

# 5. Criar tabelas + papéis base
python -m scripts.bootstrap_dev

# 6. Criar o primeiro usuário administrador
python -m scripts.criar_usuario "Nome Completo" admin@instituto.org "senha-bem-forte" administrador

# 7. Rodar a API
uvicorn app.main:app --reload
```

A API sobe em `http://127.0.0.1:8000`. Documentação interativa automática (OpenAPI/Swagger) em `http://127.0.0.1:8000/docs`.

### Testar o login manualmente

```bash
curl -i -c cookies.txt -X POST http://127.0.0.1:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@instituto.org", "senha": "senha-bem-forte"}'

curl -i -b cookies.txt http://127.0.0.1:8000/api/auth/me

curl -i -b cookies.txt -X POST http://127.0.0.1:8000/api/auth/logout
```

## Rodar os testes automatizados

Os testes usam SQLite em memória (não precisam do Postgres rodando):

```bash
DATABASE_URL="sqlite+aiosqlite:///:memory:" pytest -v
```

## Estrutura de pastas

```
app/
├── main.py            # aplicação FastAPI, monta os routers
├── config.py           # configuração via variáveis de ambiente
├── database.py          # engine/sessão async do SQLAlchemy
├── errors.py            # ApiError + formato padrão de erro (nunca vaza stack trace)
├── auth/
│   ├── models.py         # Sessao, Auditoria
│   ├── schemas.py         # LoginRequest/LoginResponse
│   ├── security.py        # hash de senha e de token de sessão
│   ├── rate_limit.py       # limite de tentativas de login
│   ├── repository.py       # única camada que fala com o banco
│   ├── service.py         # regra de negócio de login/logout
│   ├── dependencies.py      # get_current_user + exigir_papel(...)
│   └── router.py          # POST /login, POST /logout, GET /me
└── usuarios/
    └── models.py          # Usuario, Papel, UsuarioPapel

scripts/
├── bootstrap_dev.py        # cria tabelas + papéis base (atalho de dev)
└── criar_usuario.py         # cria um usuário com papel (ex.: primeiro admin)

tests/
├── conftest.py           # fixtures (SQLite em memória, client HTTP de teste)
└── test_auth.py          # 8 testes do fluxo de autenticação
```

Próximo módulo natural, seguindo `SDP_ROADMAP_DESENVOLVIMENTO.md`: Sprint 5 completa (aplicar `exigir_papel(...)` nos primeiros endpoints reais) e Sprint 6 (cadastro de pessoas atendidas).
