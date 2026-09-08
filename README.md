# Sentindo a Dor do Próximo

Sistema de gestão interna para um instituto de ação social sem fins lucrativos, cobrindo cadastro de pessoas atendidas, catálogo de serviços gratuitos (consultas, cursos, atendimento jurídico, entre outros), verificação de elegibilidade, agendamento e atendimento — com controle de acesso baseado em papéis (RBAC) e auditoria completa desde o primeiro módulo.

**Este é um projeto real**, para um instituto real que atende pessoas em situação de vulnerabilidade — não um exercício acadêmico. Toda decisão de segurança, privacidade e integridade de dados é tratada como obrigatória de produção.

## Status

🚧 Em desenvolvimento — documentação de requisitos, arquitetura e regras de negócio em andamento; parte do banco de dados já inicializável (tabelas que não dependem de decisão do instituto); implementação do Backend ainda não iniciada. Várias decisões de negócio e técnicas seguem em aberto — ver [`docs/SDP_DECISOES_PENDENTES.md`](./docs/SDP_DECISOES_PENDENTES.md).

## Stack técnica

- **Backend**: Python + FastAPI (API REST)
- **Banco de dados**: PostgreSQL, em nuvem, nunca exposto publicamente
- **Containerização**: Docker + Docker Compose
- **Frontend**: desenvolvido separadamente, tecnologia a definir pela outra equipe; convive no mesmo repositório em `frontend/`

Sem componente de IA, sem chat integrado, sem cobrança/monetização — exclusões confirmadas, ver `docs/REQUISITOS.md`, seção 7.

## Documentação

Toda a documentação do projeto vive em [`docs/`](./docs):

| Documento | Conteúdo |
|---|---|
| [`SDP_DOCUMENTACAO_PROJETO.md`](./docs/SDP_DOCUMENTACAO_PROJETO.md) | Visão geral, requisitos, arquitetura, regras de negócio, segurança, modelo de dados conceitual, esqueleto de API e roadmap — documento guarda-chuva do projeto |
| [`SDP_DECISOES_PENDENTES.md`](./docs/SDP_DECISOES_PENDENTES.md) | Decisões de negócio (só o instituto responde) e técnicas (equipe aprova) ainda em aberto — nada deve ser assumido além do que está aqui |
| [`REQUISITOS.md`](./docs/REQUISITOS.md) | Problema, objetivo, atores, requisitos funcionais e não funcionais, escopo do MVP |
| [`ARQUITETURA.md`](./docs/ARQUITETURA.md) | Componentes, fluxo de segurança, estrutura de pastas, decisões técnicas |
| [`REGRAS_NEGOCIO.md`](./docs/REGRAS_NEGOCIO.md) | Princípio do menor privilégio, elegibilidade, RBAC, atendimento e histórico |
| [`BANCO_DADOS.md`](./docs/BANCO_DADOS.md) | DER conceitual, tabelas já seguras para rascunho, tabelas bloqueadas por decisão pendente |

`SEGURANCA.md`, `API.md` e `ROADMAP_DESENVOLVIMENTO.md` ainda não existem como documentos próprios — hoje vivem dentro de `SDP_DOCUMENTACAO_PROJETO.md` (seções 5, 7 e 8) e devem ser desmembrados quando o conteúdo crescer o suficiente para justificar um arquivo separado.

## Princípios do projeto

- **Segurança não é módulo, é requisito transversal** — acompanha o projeto desde a primeira tabela, não é deixada para o final.
- **O Backend é a única fonte de verdade sobre permissão e regra de negócio** — o Frontend nunca decide sozinho o que um usuário pode ver ou fazer.
- **Nenhuma decisão de elegibilidade é inventada pelo sistema** — critérios vêm do instituto; toda decisão é auditável (quem, quando, com base em quê).
- **Nada é presumido de um projeto de referência de outro domínio.** Padrões estruturais (camadas, auditoria append-only, RBAC) são reaproveitados; regras de negócio específicas de outro domínio não são copiadas sem revalidação — ver a ressalva em `docs/SDP_DOCUMENTACAO_PROJETO.md`, seção 1.4.

## Como rodar (ambiente de desenvolvimento)

```bash
git clone https://github.com/AdminFreitas/sentindo_a_dor_do_proximo.git
cd sentindo_a_dor_do_proximo
cp .env.example .env   # preencher com valores locais — nunca versionar o .env
docker compose up --build
```

Hoje o `docker compose up` sobe **apenas o banco de dados** — o serviço `backend` só entra no `docker-compose.yml` na Sprint 3 (`docs/SDP_DOCUMENTACAO_PROJETO.md`, seção 8), quando a API FastAPI existir de fato. Até lá, o Backend roda fora do Docker, direto no ambiente Python local, conectando em `localhost:5432`.

O `.env` precisa de **duas senhas de banco diferentes** (`DB_ADMIN_PASSWORD` e `APP_DB_PASSWORD`) — ver `docs/ARQUITETURA.md`, seção 7, e o motivo em `docs/BANCO_DADOS.md`, seção 3. Ao subir pela primeira vez, `db/init/db_init.sql` cria apenas as tabelas que não dependem de nenhuma decisão pendente do instituto (ver `docs/SDP_DECISOES_PENDENTES.md`) — o restante do schema chega por migration assim que essas decisões forem fechadas.

Este repositório é compartilhado com a pessoa responsável pelo Frontend — o Backend fica isolado em `backend/`, sem misturar código com `frontend/`.

## Licença

Distribuído sob a licença MIT — ver [`LICENSE`](./LICENSE).