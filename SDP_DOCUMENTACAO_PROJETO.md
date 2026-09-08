# Documentação do Projeto — Sentindo a Dor do Próximo

> Sistema de gestão para instituto/ONG sem fins lucrativos, responsável por organizar pessoas atendidas, serviços gratuitos, elegibilidade, agendamentos, atendimentos e histórico.

**Versão do documento:** 1.0 (rascunho para aprovação)
**Data:** 08/09/2026
**Status do projeto:** 📋 Fase de documentação — nenhuma linha de código foi escrita ainda. Este documento é a base a partir da qual a arquitetura técnica e o schema de banco de dados serão derivados.

> **Como ler este documento.** Cada afirmação abaixo está marcada com um destes três selos:
> - ✅ **Confirmado** — fato de negócio já validado com quem trouxe o projeto.
> - 🔧 **Recomendação técnica** — proposta minha, com justificativa, que a equipe técnica deve aprovar ou ajustar.
> - ❓ **Decisão do instituto** — só o cliente/instituto pode responder; **não deve ser assumido nem inventado**. Está listada em detalhe no documento complementar [`SDP_DECISOES_PENDENTES.md`](./SDP_DECISOES_PENDENTES.md).
>
> Nenhum código deve ser escrito a partir de uma seção ❓ até ela virar ✅.

---

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Requisitos](#2-requisitos)
3. [Arquitetura proposta](#3-arquitetura-proposta)
4. [Regras de negócio](#4-regras-de-negócio)
5. [Segurança e privacidade](#5-segurança-e-privacidade)
6. [Modelo de dados conceitual](#6-modelo-de-dados-conceitual)
7. [API — esqueleto de contrato](#7-api--esqueleto-de-contrato)
8. [Roadmap de desenvolvimento](#8-roadmap-de-desenvolvimento)
9. [Referências e próximos documentos](#9-referências-e-próximos-documentos)

---

## 1. Visão geral

### 1.1 Problema — ✅ Confirmado

Institutos e ONGs que oferecem serviços gratuitos (consultas, cursos, atendimento jurídico, entre outros) a pessoas em situação de vulnerabilidade costumam ter recursos limitados frente à demanda. Sem um sistema que organize cadastro, análise de elegibilidade e agendamento, o instituto corre o risco de: perder o controle de quem já foi atendido, alocar recursos escassos sem critério auditável, e não conseguir demonstrar de forma transparente (a doadores, órgãos de fiscalização ou auditoria interna) como as decisões de atendimento foram tomadas.

### 1.2 Objetivo — ✅ Confirmado

Construir um sistema que permita ao instituto:
- Cadastrar pessoas atendidas;
- Oferecer um catálogo de serviços gratuitos variados (não um único tipo de serviço);
- Verificar a situação/elegibilidade da pessoa para o serviço solicitado;
- Agendar e registrar o atendimento;
- Manter histórico e auditoria de todo o processo.

### 1.3 Fluxo principal do negócio — ✅ Confirmado

```
Pessoa entra em contato ou vai até a unidade
        │
        ▼
Funcionário realiza o cadastro
        │
        ▼
Pessoa solicita / é encaminhada a um serviço
        │
        ▼
Sistema apoia a verificação de situação e elegibilidade
        │
        ▼
Funcionário realiza o agendamento (se elegível/disponível)
        │
        ▼
Atendimento
        │
        ▼
Histórico e auditoria
```

A pessoa atendida **não acessa o sistema diretamente** no modelo atual — o contato acontece por meio do funcionário ou de outros canais do instituto (a definir pelo instituto, fora do escopo técnico deste sistema por ora).

### 1.4 O que este projeto **não é** — ✅ Confirmado

Diferente de outros sistemas que podem ter servido de inspiração de estrutura documental, este projeto **não envolve**:
- Inteligência artificial / chatbot / agente autônomo;
- Chat integrado ou qualquer canal de mensagens em tempo real;
- Cobrança, pagamento ou monetização de qualquer serviço;
- Dados clínicos/prontuário no sentido de uma clínica de saúde (a menos que um dos serviços oferecidos seja da área da saúde — a confirmar, ver documento de decisões pendentes).

Isso é dito explicitamente porque a documentação foi elaborada com apoio de um projeto de outro domínio (clínica odontológica) como referência estrutural — **nenhum requisito específico daquele projeto (prontuário, CPF imutável por regra odontológica, Ollama, etc.) deve ser copiado sem revalidação para este.**

---

## 2. Requisitos

### 2.1 Atores do sistema

| Ator | Descrição | Status |
|---|---|---|
| Administrador | Configuração geral do sistema, gerenciamento de usuários e papéis, cadastro de serviços | 🔧 Recomendação |
| Gestor | Visão gerencial/relatórios; acompanha capacidade, serviços e atendimentos; **sem** permissão de alteração ampla por padrão | 🔧 Recomendação |
| Funcionário | Cadastra pessoas, solicita serviços em nome delas, realiza agendamentos, registra atendimentos dentro do que sua função autoriza | ✅ Confirmado (o fluxo já define que é o funcionário quem cadastra e agenda) |
| Avaliador de elegibilidade | Papel separado, responsável por analisar critérios e registrar decisão de elegibilidade | ❓ Decisão do instituto — existe essa função separada na operação real, ou é o próprio funcionário que avalia? (ver D05) |
| Auditor | Consulta auditoria e histórico; sem permissão de alteração | 🔧 Recomendação |
| Pessoa atendida | Beneficiária dos serviços; não acessa o sistema diretamente no MVP | ✅ Confirmado |
| Organização | O instituto em si e, possivelmente, organizações parceiras | ❓ Decisão do instituto (ver D02) |

### 2.2 Requisitos funcionais

| ID | Requisito | Descrição | Status |
|---|---|---|---|
| RF01 | Autenticação | Login, logout real (com revogação de sessão), hash seguro de senha, ativação/desativação de usuário | 🔧 Recomendação |
| RF02 | Cadastro de pessoas atendidas | Dados de identificação e contato mínimos necessários (definir campos exatos — ver D06); edição com histórico/auditoria | 🔧 Recomendação de estrutura |
| RF03 | Cadastro de funcionários e papéis | Funcionário vinculado a um usuário, com papel(éis) associados | 🔧 Recomendação |
| RF04 | Catálogo de serviços | Serviço genérico e extensível — nome, descrição, organização responsável, capacidade, disponibilidade, se exige avaliação de elegibilidade | ✅ Confirmado que precisa ser genérico (consultas, cursos, atendimento jurídico, outros); campos exatos 🔧 recomendação |
| RF05 | Avaliação de elegibilidade | Registro de decisão (elegível / não elegível / em avaliação / necessita revisão), responsável, critérios usados, justificativa | ✅ Confirmado que deve existir e ser auditável; modelo exato (geral vs. por serviço) ❓ D01 |
| RF06 | Agendamento | Vincula pessoa + serviço + funcionário + data/hora; impede conflito e estouro de capacidade | ✅ Confirmado como etapa do fluxo |
| RF07 | Registro de atendimento | Marca o serviço como realizado, com dados mínimos do que foi feito | ✅ Confirmado como etapa do fluxo; detalhe exato ❓ D04 |
| RF08 | Auditoria | Registro de quem fez o quê, quando e sobre qual registro, para toda operação sensível — especialmente decisões de elegibilidade | ✅ Confirmado como prioridade do projeto |
| RF09 *(condicional)* | Organizações parceiras | Suporte a mais de uma organização oferecendo serviços | ❓ D02 |
| RF10 *(futuro)* | Relatórios gerenciais | Relatórios de capacidade, atendimentos por serviço, etc. | 🔧 Recomendação de fase futura |

### 2.3 Requisitos não funcionais

| ID | Requisito | Descrição |
|---|---|---|
| RNF01 | Segurança | As regras da seção 5 são requisito, não recomendação — o sistema lida com dados pessoais de pessoas em situação de vulnerabilidade |
| RNF02 | Privacidade e minimização de dados | Coletar apenas o que tem finalidade definida; nada de "pode ser útil no futuro" |
| RNF03 | Auditabilidade | Toda decisão relevante (especialmente elegibilidade) é rastreável: quem, quando, com base em quê |
| RNF04 | Integridade sob concorrência | Dois agendamentos não podem ocupar a mesma vaga/horário simultaneamente |
| RNF05 | Usabilidade | Um funcionário sem treinamento técnico consegue cadastrar uma pessoa e solicitar um serviço após explicação breve |
| RNF06 | Portabilidade | Ambiente de desenvolvimento reproduzível (Docker/Docker Compose) |
| RNF07 | Desempenho | Meta concreta (ex.: P95 de latência) a ser definida após uma primeira medição real — "tempo aceitável" sozinho não é uma meta verificável |

### 2.4 Fora do escopo inicial — 🔧 Recomendação (sujeita a confirmação do instituto)

- Aplicativo mobile nativo (sistema web responsivo cobre a necessidade inicial);
- Inteligência artificial de qualquer tipo;
- Chat integrado;
- Cobrança/monetização;
- Organizações parceiras completas (até D02 ser respondida).

### 2.5 Critérios de aceitação do MVP — 🔧 Recomendação (a validar com o instituto)

- Funcionário cadastra uma pessoa e consegue solicitar um serviço para ela.
- Sistema apresenta o resultado da verificação de elegibilidade (mesmo que a decisão final ainda dependa de avaliação humana).
- Funcionário consegue agendar sem conflito de horário/capacidade.
- Atendimento é registrado e aparece no histórico da pessoa.
- Toda decisão de elegibilidade fica auditada com responsável e critério.
- Usuário sem permissão para um recurso recebe erro de autorização, não o dado.

---

## 3. Arquitetura proposta

> Toda esta seção é 🔧 **recomendação técnica**, elaborada a partir do fluxo de negócio confirmado. Nenhuma tecnologia aqui deve ser considerada "decidida" até validação formal da equipe técnica/cliente.

### 3.1 Visão geral

```
Usuário (funcionário/gestor/admin)
        ↓ HTTPS
Frontend Web Responsivo
        ↓ HTTPS
Backend — API REST
        ↓ rede privada (nunca pública)
PostgreSQL
```

Justificativa: o público de acesso é interno (funcionários do instituto), não o público geral — não há necessidade, hoje, de canal de contato automatizado (IA/chat) dentro do sistema. O banco de dados nunca deve ser exposto diretamente à internet; todo acesso passa pelo Backend.

### 3.2 Fluxo obrigatório de segurança

```
Usuário → Autenticação → Autorização → Validação → Regra de negócio → Banco de dados
```

O Frontend nunca é a camada que garante segurança — esconder uma opção de menu não substitui a verificação no Backend.

### 3.3 Stack recomendada

| Camada | Proposta | Justificativa |
|---|---|---|
| Backend | **FastAPI** (Python) | Tipagem e validação de schema nativas (Pydantic), geração automática de contrato OpenAPI — útil porque o Frontend será construído separadamente, e Python facilita onboarding de equipe. Alternativas válidas (Flask, Django, Node/Nest) — se a equipe já tiver stack definida, ela prevalece. |
| Banco de dados | **PostgreSQL** | Necessidade de integridade relacional, transações, controle de concorrência em agendamento e histórico auditável — mesmos motivos estruturais de qualquer sistema de agendamento com múltiplos usuários simultâneos. |
| Frontend | Web responsivo (SPA), tecnologia a definir pela equipe | Cobre desktop/tablet/celular sem manter três códigos-base (web/Android/iOS) desde o início; API fica pronta para um app nativo futuro se necessário. |
| Hospedagem | Nuvem, com banco em rede privada (nunca exposto publicamente) | Evita dependência de uma única máquina física do instituto (energia, backup manual, risco de furto/perda de equipamento). |
| Containerização | Docker + Docker Compose para desenvolvimento | Ambiente reprodutível entre membros da equipe (RNF06). |

### 3.4 Padrão de arquitetura: monólito modular

```
backend/
├── auth/           # autenticação e sessão
├── usuarios/        # contas de acesso e papéis
├── pessoas/         # cadastro de pessoas atendidas
├── funcionarios/     # cadastro de funcionários
├── organizacoes/     # instituto e (se aplicável) parceiros
├── servicos/         # catálogo de serviços
├── elegibilidade/     # avaliação e decisão de elegibilidade
├── agendamentos/      # agenda e agendamento
├── atendimentos/      # registro de atendimento realizado
├── auditoria/        # trilha de auditoria
├── shared/          # utilitários, middlewares de auth/autorização
└── main.py
```

Justificativa de **não** usar microserviços agora: o sistema não tem, hoje, necessidade de escalar componentes de forma independente, e microserviços aumentam custo operacional, complexidade de comunicação entre serviços e superfície de falha sem benefício correspondente neste estágio. Separação em módulos dentro de um monólito permite organização clara e migração futura para serviços separados **se e quando** houver necessidade real.

Regra de dependência (mesmo princípio usado em sistemas em camadas): `rotas → serviços (regra de negócio) → repositórios (acesso a dado) → banco`. Nunca o inverso.

### 3.5 Estratégia de autenticação — proposta explícita (evitando ambiguidade)

> Nota: em um documento anterior de outro projeto, essa mesma decisão ficou ambígua (Bearer Token vs. cookie) e isso foi identificado como falha crítica. Aqui a proposta é explícita desde o início.

- **Sessões controladas pelo servidor**, não JWT stateless puro.
- Cookie de sessão `HttpOnly` + `Secure` + `SameSite=Strict`.
- Senha armazenada apenas como hash (Argon2id ou bcrypt).
- Tabela de sessões no banco permite: logout real (revogação), expiração, e invalidação imediata de todas as sessões de um usuário desativado.
- Autenticação multifator (MFA) recomendada para Administrador e outros papéis de alto privilégio.
- Nenhum token/sessão é armazenado em `localStorage`/`sessionStorage` do navegador.

---

## 4. Regras de negócio

> Esta seção define **conceitos**, não o schema definitivo do banco — o schema depende de decisões ainda em aberto (seção 6 e documento de decisões pendentes).

### 4.1 Princípio do menor privilégio — 🔧 Recomendação

Todo usuário recebe apenas o acesso mínimo necessário à sua função. Acesso técnico de desenvolvimento/infraestrutura (deploy, banco, secrets) **não é um papel de negócio da aplicação** — é controlado separadamente, fora do sistema, com contas de infraestrutura próprias.

### 4.2 Controle de acesso (RBAC) — 🔧 Recomendação preliminar

| Recurso | Administrador | Gestor | Funcionário | Avaliador¹ | Auditor |
|---|---|---|---|---|---|
| Cadastro de pessoas | Leitura | Leitura | Leitura/Escrita | Leitura | Leitura |
| Cadastro de funcionários/papéis | Leitura/Escrita | Leitura | — | — | — |
| Catálogo de serviços | Leitura/Escrita | Leitura | Leitura | Leitura | — |
| Solicitação de serviço | Leitura | Leitura | Leitura/Escrita | Leitura | Leitura |
| Avaliação de elegibilidade | Leitura | Leitura | Leitura² | Leitura/Escrita | Leitura |
| Agendamento | Leitura | Leitura | Leitura/Escrita | — | Leitura |
| Atendimento (registro) | Leitura | Leitura | Leitura/Escrita | — | Leitura |
| Auditoria/Logs | — | Leitura | — | — | Leitura |
| Configuração do sistema | Leitura/Escrita | — | — | — | — |

¹ Papel só existe se o instituto confirmar que a avaliação de elegibilidade é uma função separada da operação normal do funcionário — ver D05. Se não existir, suas permissões vão para "Funcionário".
² Se não existir papel de Avaliador separado, Funcionário também tem escrita em elegibilidade.

Célula em branco = **sem acesso** (não implícito). Esta tabela é a fonte única de verdade de autorização — qualquer exceção deve ser adicionada aqui antes de virar código.

### 4.3 Pessoa atendida — 🔧 Recomendação de estrutura, ❓ campos exatos (D06)

Conceito: indivíduo cadastrado pelo instituto para receber um ou mais serviços. Dados de identificação/contato mínimos ainda a definir com o instituto (o que é realmente necessário coletar, respeitando minimização de dados — seção 5.2).

### 4.4 Serviço — ✅ estrutura genérica confirmada

Um Serviço é uma oferta do instituto (consulta, curso, atendimento jurídico, outro) com: nome, descrição, organização responsável, capacidade, disponibilidade, e se exige avaliação de elegibilidade prévia. **Não** deve haver uma tabela específica por tipo de serviço — o núcleo trata "Serviço" de forma genérica; características específicas de um tipo (ex.: pré-requisitos de um curso) são extensão, não uma entidade paralela.

### 4.5 Elegibilidade — ✅ princípio confirmado, ❓ modelo exato (D01)

Como os recursos do instituto são limitados e os serviços são gratuitos, o sistema precisa apoiar (não substituir) a decisão de quem recebe o serviço, de forma auditável — nunca baseada em impressão subjetiva não registrada ("parece precisar").

Estados conceituais:
```
PENDENTE → EM_AVALIACAO → { ELEGIVEL | NAO_ELEGIVEL | NECESSITA_REVISAO }
```

Toda decisão relevante registra: responsável, data, critérios usados e justificativa quando aplicável.

**Regra explícita:** o sistema pode organizar dados, verificar critérios objetivos e sinalizar inconsistências — mas **não inventa critério de elegibilidade**. Os critérios (o que conta, o que é obrigatório, quem aprova, quem revisa) são definidos formalmente pelo instituto — ver D01 no documento de decisões pendentes. Enquanto D01 não for respondida, o módulo de elegibilidade não pode ser modelado em definitivo no banco.

### 4.6 Agendamento — ✅ confirmado como etapa do fluxo

Vincula pessoa, serviço, funcionário responsável e horário. Regra obrigatória: impedir conflito de horário e estouro de capacidade — garantido preferencialmente no próprio banco (constraint), não só na aplicação, pelo mesmo motivo de qualquer sistema de agendamento concorrente: checar-e-salvar na aplicação não é uma operação atômica.

### 4.7 Atendimento e histórico — ✅ confirmado como etapa do fluxo, ❓ detalhe exato (D04)

Registra que o serviço foi efetivamente realizado. O que exatamente fica registrado (resultado, observações, próximos passos) depende de como cada tipo de serviço opera na prática — ver D04.

---

## 5. Segurança e privacidade

### 5.1 Regra fundamental — 🔧 Recomendação

```
Usuário → Autenticação → Autorização → Validação → Regra de negócio → Banco de dados
```

O Frontend nunca garante segurança sozinho; o Backend nega com `403 Forbidden` independentemente do que o cliente enviar.

### 5.2 Privacidade por padrão e minimização de dados — ✅ princípio confirmado

- Dados de pessoas atendidas **não são públicos** — o sistema não é uma rede social nem um diretório público.
- Cada dado coletado precisa ter finalidade definida antes de ser coletado. Nada de "pode ser útil no futuro".
- Classificação inicial de dados: **Interno** (dados administrativos), **Confidencial** (contato, endereço, documentos), **Alta proteção** (informações sobre situação social/vulnerabilidade, decisão de elegibilidade e sua justificativa).
- Embora "situação socioeconômica" não seja, por si só, uma categoria de dado sensível listada no art. 5º, II da LGPD (diferente de dado de saúde, origem racial, convicção religiosa etc.), o tratamento cuidadoso desse tipo de informação é uma exigência ética e reputacional direta do projeto — o instituto trabalha com pessoas em situação de vulnerabilidade, e um vazamento tem impacto real sobre elas. Trate como alta proteção por política própria do projeto, independentemente da classificação legal estrita.

### 5.3 Checklist de segurança — 🔧 Recomendação (adaptado do padrão de mercado, a validar)

1. Nunca expor secrets no código, Frontend ou repositório — variáveis de ambiente/gerenciador de secrets.
2. Secrets vazados são revogados e substituídos, nunca só removidos do próximo commit.
3. Hash seguro de senha (Argon2id ou bcrypt).
4. Autenticação sempre validada no servidor — nunca confiar em identidade enviada pelo cliente.
5. RBAC verificado em todo endpoint sensível (seção 4.2).
6. Princípio do menor privilégio (seção 4.1).
7. Criptografia de dados sensíveis em repouso — mecanismo e gestão de chave a definir (ver documento de decisões pendentes).
8. HTTPS obrigatório em toda comunicação.
9. Cookies de sessão seguros (`HttpOnly`, `Secure`, `SameSite`).
10. Queries parametrizadas — nunca concatenar SQL com dado do usuário.
11. Validação e sanitização de toda entrada da API.
12. Proteção contra Mass Assignment — campos alteráveis definidos explicitamente por operação.
13. Rate limiting em login e endpoints sensíveis.
14. Headers de segurança (CSP, HSTS, X-Content-Type-Options).
15. Auditoria de eventos sensíveis (login, falha de login, alteração de permissão, decisão de elegibilidade, alteração cadastral).
16. Varredura de dependências (SCA).
17. Backup seguro, criptografado e **testado** (backup nunca restaurado em teste não conta como estratégia de recuperação).

### 5.4 Teste obrigatório: IDOR

```
Login como funcionário sem relação com a pessoa 101
GET /api/pessoas/101 → deve retornar 403, nunca o dado
```

### 5.5 Auditoria — ✅ prioridade confirmada, 🔧 estrutura recomendada

Eventos mínimos a auditar: login, logout, falha de login, criação/alteração de pessoa, solicitação de serviço, decisão de elegibilidade e sua alteração, agendamento, cancelamento, registro de atendimento, alteração de usuário/permissão.

Cada registro de auditoria identifica: quem, quando, qual ação, qual recurso, resultado. A tabela de auditoria deve ser somente-inserção (sem `UPDATE`/`DELETE` disponível para o usuário de aplicação) — auditoria que pode ser editada não serve como evidência.

---

## 6. Modelo de dados conceitual

> ⚠️ **Este NÃO é o schema definitivo.** Migrar isso para DDL completo antes de fechar D01 (modelo de elegibilidade) e D02 (organizações) geraria retrabalho de banco já em produção. O DER abaixo é conceitual, para orientar a conversa com o instituto — não para ser executado.

### 6.1 Entidades e relacionamentos (conceitual)

```
usuarios (1) ──── (1) funcionarios
usuarios (1) ──── (N) auditoria

organizacoes (1) ──── (N) servicos            [se D02 confirmar múltiplas organizações]

pessoas (1) ──── (N) solicitacoes_servico
solicitacoes_servico (N) ──── (1) servicos
solicitacoes_servico (1) ──── (0..1) avaliacoes_elegibilidade   [modelo depende de D01]

solicitacoes_servico (1) ──── (0..1) agendamentos
agendamentos (1) ──── (0..1) atendimentos
```

### 6.2 Entidades já seguras para rascunho de tabela (independem de D01/D02)

```sql
-- Rascunho preliminar — sujeito a revisão, NÃO é definitivo.

CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE papeis (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(30) UNIQUE NOT NULL
        CHECK (nome IN ('administrador','gestor','funcionario','avaliador','auditor'))
);

CREATE TABLE usuarios_papeis (
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    papel_id INTEGER NOT NULL REFERENCES papeis(id),
    PRIMARY KEY (usuario_id, papel_id)
);

CREATE TABLE sessoes (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    token_hash VARCHAR(255) NOT NULL,
    criado_em TIMESTAMP NOT NULL DEFAULT now(),
    expira_em TIMESTAMP NOT NULL,
    revogado_em TIMESTAMP,
    ip VARCHAR(45)
);

CREATE TABLE auditoria (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id),
    tabela VARCHAR(50) NOT NULL,
    registro_id INTEGER,
    acao VARCHAR(30) NOT NULL CHECK (acao IN (
        'CRIACAO','ALTERACAO','EXCLUSAO','LEITURA_SENSIVEL',
        'LOGIN','LOGIN_FALHOU','LOGOUT',
        'PERMISSAO_NEGADA','PAPEL_ALTERADO','USUARIO_DESATIVADO'
    )),
    dado_anterior JSONB,
    dado_novo JSONB,
    ip VARCHAR(45),
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);
REVOKE UPDATE, DELETE ON auditoria FROM app_runtime;
```

`pessoas`, `servicos`, `agendamentos`, `atendimentos` e a estrutura de `elegibilidade`/`organizacoes` ficam de fora deste rascunho até D01/D02/D06 serem respondidas — desenhar essas tabelas antes disso arrisca ter que refazer migração em produção.

---

## 7. API — esqueleto de contrato

> Esqueleto inicial, para orientar o Frontend a começar em paralelo. Endpoints de elegibilidade e organizações ficam como placeholder até D01/D02.

### 7.1 Códigos HTTP

| Código | Uso |
|---|---|
| 200 | Sucesso |
| 201 | Criado |
| 400 | Requisição malformada |
| 401 | Não autenticado |
| 403 | Sem permissão (RBAC) |
| 404 | Recurso não existe |
| 409 | Conflito de regra de negócio (ex.: horário sobreposto) |
| 422 | Dado bem formado, mas inválido pela regra de negócio |
| 429 | Rate limit acionado |
| 500 | Erro interno — nunca retorna stack trace/detalhe interno ao cliente |
| 503 | Dependência indisponível |

### 7.2 Endpoints iniciais

```
POST   /api/auth/login
POST   /api/auth/logout

GET    /api/pessoas
POST   /api/pessoas
GET    /api/pessoas/{id}
PUT    /api/pessoas/{id}

GET    /api/servicos
POST   /api/servicos
PUT    /api/servicos/{id}

POST   /api/solicitacoes-servico
GET    /api/solicitacoes-servico/{id}

# placeholder — contrato definitivo depende de D01
POST   /api/elegibilidade/avaliar
GET    /api/elegibilidade/{solicitacao_id}

GET    /api/agenda?funcionario_id={id}&data={YYYY-MM-DD}
POST   /api/agendamentos
PATCH  /api/agendamentos/{id}/cancelar

POST   /api/atendimentos

GET    /api/auditoria?tabela=&registro_id=&usuario_id=
```

Formato padrão de erro (recomendação):
```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Recurso não encontrado",
    "request_id": "..."
  }
}
```

---

## 8. Roadmap de desenvolvimento

> 🔧 Recomendação — segue a mesma lógica de "não avançar sem critério de aceitação cumprido" usada como boa prática em projetos anteriores.

| Sprint | Foco | Depende de |
|---|---|---|
| 0 | Requisitos (este documento) | — |
| 1 | Regras de negócio detalhadas + arquitetura | Resposta às decisões D01–D06 |
| 2 | Banco de dados definitivo | Sprint 1 |
| 3 | Backend base (estrutura, config, logs) | Sprint 2 |
| 4 | Autenticação e sessão | Sprint 3 |
| 5 | Autorização (RBAC) | Sprint 4 |
| 6 | Cadastro de pessoas | Sprint 5 |
| 7 | Catálogo de serviços | Sprint 5 |
| 8 | Elegibilidade | D01 respondida |
| 9 | Agendamento | Sprint 8 |
| 10 | Atendimento e histórico | Sprint 9 |
| 11 | Frontend do MVP | Sprint 5 em diante (paralelo) |
| 12 | Testes automatizados | Sprint 11 |
| 13 | Auditoria de segurança (checklist seção 5.3 + teste IDOR) | Sprint 12 |
| 14 | Revisão de privacidade/LGPD | Sprint 13 |
| 15 | Testes de usabilidade e aceitação | Sprint 14 |
| 16 | Homologação | Sprint 15 |
| 17 | Deploy | Backup/DR e ambientes definidos (ver decisões pendentes) |
| 18 | Entrega | Sprint 17 |

---

## 9. Referências e próximos documentos

- [`SDP_DECISOES_PENDENTES.md`](./SDP_DECISOES_PENDENTES.md) — decisões de negócio (só o instituto responde) e decisões técnicas (equipe aprova) que precisam ser fechadas antes da Sprint 2.
- Próximo documento recomendado após fechar as decisões pendentes: `REGRAS_DE_NEGOCIO_DETALHADO.md`, definindo com precisão os conceitos de Pessoa, Serviço, Solicitação, Elegibilidade, Disponibilidade, Agendamento, Atendimento, Cancelamento e Histórico — antes de qualquer schema definitivo de banco.
