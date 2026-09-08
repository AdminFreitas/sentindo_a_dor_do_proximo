# Arquitetura do Sistema — Sentindo a Dor do Próximo

## 1. Visão geral

```text
Usuário (funcionário/gestor/administrador)
        ↓
Frontend Web Responsivo
        ↓
Backend [Servidor] — FastAPI REST API
        ↓
PostgreSQL (Banco de Dados)
```

> Diferente do projeto de referência usado como base estrutural (uma clínica com atendimento inicial por IA), **este sistema não tem componente de inteligência artificial** — ver `REQUISITOS.md`, seção 7, e `SDP_DOCUMENTACAO_PROJETO.md`, seção 1.4. A pessoa atendida não interage com o sistema diretamente; o contato acontece por meio do funcionário.

O Frontend nunca acessa o banco diretamente. Toda escrita ou leitura de dado passa pelo Backend, que é o único componente com credencial de banco.

## 2. Fluxo obrigatório de segurança

Toda requisição passa pela mesma sequência, sem exceção:

```text
Usuário
   ↓
Autenticação   (quem é você?)
   ↓
Autorização    (o que você pode fazer?)
   ↓
Validação      (o dado enviado é válido?)
   ↓
Regra de negócio  (isso é permitido nesse contexto?)
   ↓
Banco de dados
```

Regra fixa: **o Frontend nunca é responsável por segurança.** Esconder um botão ou menu no Frontend não substitui a verificação no Backend — toda ação sensível é validada no servidor, mesmo que a interface já "pareça" impedir.

## 3. Componentes

- **Frontend**: consome a API REST do Backend; tecnologia a ser definida pela equipe (SPA responsiva); não guarda dado persistente localmente além do necessário para a sessão (nunca o token/sessão em `localStorage`/`sessionStorage` — ver `SDP_DOCUMENTACAO_PROJETO.md`, seção 3.5).
- **Backend**: Python + FastAPI, organizado em módulos por domínio (seção 5).
- **Banco de dados**: PostgreSQL — justificativa na seção 6.
- **Containerização**: Docker + Docker Compose orquestrando Backend e banco em ambiente de desenvolvimento reprodutível.

## 4. Estrutura de pastas sugerida

Diferente do padrão "por camada" (routes/services/repositories como pastas de topo), aqui a estrutura é organizada **por módulo de domínio primeiro**, e dentro de cada módulo por camada — mais adequado a FastAPI e ao fato de o Backend crescer em domínios de negócio distintos (elegibilidade, agendamento, auditoria) que precisam evoluir de forma relativamente independente:

```text
sentindo_a_dor_do_proximo/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── core/               # config, segurança, exceções centralizadas
│   │   ├── db/                 # engine, sessão, migrations (Alembic)
│   │   ├── modules/
│   │   │   ├── auth/
│   │   │   ├── usuarios/
│   │   │   ├── pessoas/
│   │   │   ├── funcionarios/
│   │   │   ├── servicos/       # catálogo de ofertas (❓ D03 — governança)
│   │   │   ├── elegibilidade/  # ❓ D01 — modelo ainda em aberto
│   │   │   ├── agendamentos/
│   │   │   ├── atendimentos/   # ❓ D04 — o que é registrado
│   │   │   ├── auditoria/
│   │   │   └── notificacoes/
│   │   └── shared/             # utilitários cruzados, sem regra de negócio
│   ├── migrations/
│   ├── tests/
│   ├── requirements.txt / pyproject.toml
│   └── .env.example
├── db/
│   └── init/                   # scripts executados por docker-entrypoint-initdb.d
│       └── db_init.sql         # ver BANCO_DADOS.md, seção 7
├── frontend/                   # repositório compartilhado — não é responsabilidade deste documento
├── docs/
├── docker-compose.yml
├── .env.example
└── .gitignore
```

O módulo `organizacoes/` só é criado se D02 confirmar a existência de organizações parceiras.

## 5. Padrão de camadas do backend

Dentro de cada módulo:

- **router**: recebe a requisição HTTP, chama o serviço correspondente, devolve a resposta. Não contém regra de negócio.
- **service**: contém a regra de negócio (ex.: "não permitir agendamento sobreposto"). É aqui que a autorização por papel é checada antes de qualquer escrita.
- **repository**: única camada que conversa com o banco (SQLAlchemy). Nenhuma outra camada monta SQL diretamente.
- **models**: representação das tabelas do banco (ORM).
- **schemas**: validação Pydantic do formato dos dados de entrada e saída — protege contra Mass Assignment (campo não esperado é rejeitado, não ignorado silenciosamente).

Regra de dependência: `router → service → repository → banco`. Nunca o inverso, e nunca pulando uma camada.

## 6. Decisões técnicas e justificativa

**Backend: FastAPI, não Flask**
Tipagem e validação de schema nativas via Pydantic, e geração automática de contrato OpenAPI — relevante aqui porque o Frontend é desenvolvido por outra pessoa/equipe em paralelo, no mesmo repositório. Qualquer stack que a equipe já domine é aceitável (ver `SDP_DECISOES_PENDENTES.md`, T01); a arquitetura em módulos não depende do framework.

**Banco de dados: PostgreSQL**
Necessidade de integridade relacional, transações e controle de concorrência em agendamento. O recurso mais relevante herdado do projeto de referência é o `EXCLUDE constraint`, que impede sobreposição de horário diretamente no banco — aplicável assim que o modelo de disponibilidade dos serviços (individual vs. turma/vaga) estiver definido (ver `BANCO_DADOS.md`, seção 2).

**Sem componente de IA**
O projeto de referência usava um modelo local (Ollama) para triagem inicial do paciente. Este sistema não tem esse componente — decisão já confirmada (`REQUISITOS.md`, seção 7). Se isso mudar no futuro, será uma decisão nova, não uma retomada silenciosa do desenho antigo.

## 7. Ambiente de desenvolvimento (Docker Compose)

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_ADMIN_USER}
      POSTGRES_PASSWORD: ${DB_ADMIN_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - db_data:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_ADMIN_USER} -d ${DB_NAME}"]
      interval: 5s
      timeout: 5s
      retries: 5

# O serviço "backend" entra aqui na Sprint 3 (SDP_DOCUMENTACAO_PROJETO.md,
# seção 8), quando a API FastAPI existir de fato. Por enquanto ele roda
# fora do Docker, direto no ambiente Python local, conectando em
# localhost:5432 com o usuário app_runtime (criado por db/init/db_init.sql,
# não pelas variáveis DB_ADMIN_* acima, que configuram só o usuário
# dono/bootstrap).

volumes:
  db_data:
```

Nenhuma senha ou chave vai no `docker-compose.yml` — tudo vem de variáveis de ambiente carregadas de um `.env` que **não é versionado**. Note que `DB_ADMIN_PASSWORD` (usuário `db_owner`/`DB_ADMIN_USER`, dono/migração) e `APP_DB_PASSWORD` (usuário `app_runtime`, o que o Backend efetivamente usa em runtime) são **propositalmente diferentes**, para que o `REVOKE` definido em `db_init.sql` tenha efeito real (ver `SDP_DECISOES_PENDENTES.md`, T04).