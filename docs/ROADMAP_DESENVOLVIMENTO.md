# Roadmap de Desenvolvimento

> Ordem cronológica de construção do sistema, do levantamento de requisitos até a entrega. Ligado a `SDP_DOCUMENTACAO_PROJETO.md` e `SDP_DECISOES_PENDENTES.md` — nenhuma Sprint aqui avança sobre uma decisão ainda marcada como pendente nesses documentos.

## Regra de ouro da equipe

> Não avançamos para a próxima Sprint porque o prazo chegou. Avançamos quando o incremento atende aos critérios de aceitação definidos **e** está testado.

Nenhuma tarefa é considerada concluída só porque o código foi escrito. Ela precisa estar: **implementada + testada + integrada + revisada em Pull Request + documentada**.

## Visão geral das fases

```text
Requisitos → Decisões pendentes fechadas → Arquitetura → Banco de dados → Backend base →
Autenticação → Autorização → Pessoas → Serviços → Elegibilidade → Agenda → Agendamento →
Atendimento → Frontend do MVP → Testes automatizados → Segurança → Auditoria/LGPD →
Usabilidade → Aceitação → Carga → Homologação → Deploy → Entrega
```

Diferente de um roadmap genérico, aqui existe uma dependência explícita adicional: **nenhuma Sprint que envolva elegibilidade, organizações ou o papel de avaliador pode avançar em definitivo enquanto D01, D02 e D05 (`SDP_DECISOES_PENDENTES.md`) não forem respondidas pelo instituto.**

---

## Sprint 0 — Levantamento de requisitos

**Objetivo:** fechar o escopo antes de escrever qualquer código.

- Definir problema, objetivo e fluxo principal do negócio
- Confirmar os atores: administrador, gestor, funcionário, avaliador (❓ D05), auditor
- Levantar requisitos funcionais e não funcionais
- Levantar as decisões de negócio ainda em aberto e registrá-las formalmente (D01–D06)

**Entrega:** `SDP_DOCUMENTACAO_PROJETO.md` v1.0 + `SDP_DECISOES_PENDENTES.md`. Ainda não se programa nesta Sprint.

---

## Sprint 1 — Fechamento de decisões + arquitetura

**Objetivo:** decidir como o sistema vai funcionar — de negócio e tecnicamente — antes de desenhar qualquer tabela.

- Levar D01 (modelo de elegibilidade), D02 (organizações) e D05 (papel avaliador) ao instituto e obter resposta formal — **esta Sprint não termina sem isso**
- Fechar D03, D04 e D06 em paralelo, se possível
- Aprovar as decisões técnicas T01–T09 com a equipe
- Desenhar o DER definitivo (agora possível, com D01/D02/D06 respondidas)
- Desenhar a matriz de permissões (RBAC) em detalhe técnico, já refletindo se o papel avaliador existe (D05)
- Definir estrutura de pastas do repositório e padrão de organização do código (monólito modular — seção 3.4)

**Entrega:** `SDP_DOCUMENTACAO_PROJETO.md` atualizado com as decisões fechadas + DER definitivo.

**Critério de saída:** nenhum item 🔴 de `SDP_DECISOES_PENDENTES.md` continua em aberto.

---

## Sprint 2 — Banco de dados

**Objetivo:** construir a fundação. Nada é escrito no backend antes disso estar validado.

- Criar banco, tabelas, chaves primárias e estrangeiras
- Entidades da primeira leva, já sem dependência de decisão pendente: `usuarios`, `papeis`, `usuarios_papeis`, `sessoes`, `auditoria` (rascunho já em `SDP_DOCUMENTACAO_PROJETO.md` seção 6.2)
- Entidades que dependiam de D01/D02/D06 (agora fechadas na Sprint 1): `pessoas`, `funcionarios`, `servicos`, `solicitacoes_servico`, `elegibilidade` (ou equivalente conforme modelo escolhido em D01), `agendamentos`, `atendimentos`, `organizacoes` (se D02 confirmar)
- Implementar constraint de banco que impede sobreposição de horário/estouro de capacidade em `agendamentos`
- Configurar separação de usuários do PostgreSQL por privilégio (T04): `migration_owner` ≠ `app_runtime`, com `UPDATE`/`DELETE` revogado de `app_runtime` em `auditoria`
- Definir índices necessários (ex.: `agendamentos(funcionario_id, data)`)

**Testar antes de seguir:** inserir, alterar, consultar; tentar `UPDATE`/`DELETE` em `auditoria` pelo usuário de aplicação (deve falhar); tentar criar dois agendamentos sobrepostos para o mesmo funcionário/capacidade (o segundo deve falhar).

**Entrega:** banco funcional e validado por teste manual.

---

## Sprint 3 — Backend base

**Objetivo:** montar o esqueleto da API antes de qualquer funcionalidade de negócio.

- Estrutura do projeto (framework definido em T01), conexão com o banco, ORM
- Tratamento de erros padronizado (nunca expõe stack trace/detalhe interno — ver `SDP_SEGURANCA.md`), validação de entrada
- Logs de aplicação
- Documentação OpenAPI (esqueleto, cresce a cada Sprint, a partir de `SDP_API.md`)
- Configuração de variáveis de ambiente e secrets (regras 1 e 2 de `SDP_SEGURANCA.md`) desde o primeiro commit
- `GET /health` (observabilidade mínima — T08)

**Entrega:** API rodando localmente, sem funcionalidade de negócio ainda.

---

## Sprint 4 — Autenticação

- Login, logout real com revogação de sessão (tabela `sessoes`), hash de senha (Argon2id ou bcrypt)
- Sessão via cookie `HttpOnly`/`Secure`/`SameSite=Strict` com expiração
- Rate limiting em tentativas de login (regra 14 de `SDP_SEGURANCA.md`)
- MFA para administrador e papéis de alto privilégio, se aprovado em T02

**Testar:** senha correta → acesso; senha errada → bloqueio; usuário inexistente → erro; sessão expirada → acesso negado; logout → sessão realmente revogada no servidor (não só cookie apagado no navegador).

**Entrega:** sistema autenticado.

---

## Sprint 5 — Autorização (RBAC)

- Implementar os papéis definidos na tabela RBAC de `SDP_DOCUMENTACAO_PROJETO.md` seção 4.2 — já fechada quanto à existência ou não do papel avaliador (D05)
- Middleware de autorização no backend — nunca no frontend
- Testar diretamente na API, não só na tela: um funcionário tentando acessar `/api/auditoria` deve receber `403 Forbidden`

**Entrega:** controle de acesso funcionando e testado por papel.

---

## Sprint 6 — Cadastro de pessoas atendidas

- Formulário de cadastro, consulta, edição, inativação — campos conforme D06
- Endpoints com validação e checagem de autorização
- Testes: dados inválidos → negado; usuário sem permissão → negado; Mass Assignment bloqueado

**Entrega:** cadastro de pessoas funcionando de ponta a ponta.

---

## Sprint 7 — Serviços (e organizações, se D02 confirmar)

- Catálogo de serviços genérico (nome, descrição, capacidade, disponibilidade, se exige avaliação de elegibilidade)
- Se D02 confirmar múltiplas organizações: CRUD de organizações e vínculo com serviço/funcionário

**Entrega:** sistema já conhece a estrutura real de oferta do instituto.

---

## Sprint 8 — Elegibilidade

**Pré-requisito obrigatório:** D01 e D05 fechadas desde a Sprint 1 — esta Sprint não deve começar sem isso.

- Implementar o fluxo de solicitação de serviço → avaliação → decisão, conforme o modelo definido em D01
- Registro de decisão com responsável, critério e justificativa
- Auditoria de toda decisão e alteração de decisão

**Entrega:** módulo de elegibilidade funcionando conforme o modelo aprovado pelo instituto.

---

## Sprint 9 — Agenda e agendamento

- Agenda por funcionário: disponibilidade, bloqueios, capacidade por serviço
- Regra crítica: impedir sobreposição de horário/estouro de capacidade — garantida no backend/banco, não só na tela
- Fluxo: solicitação apta → seleciona funcionário → sistema mostra horários livres → confirma → agendamento criado
- Status do agendamento: `agendado`, `confirmado`, `concluído`, `cancelado`, `não compareceu`
- Validação final sempre no servidor — mesmo que o horário parecesse livre no momento da consulta, o backend recusa o conflito no momento de salvar

**Entrega:** agendamento completo, testado contra conflito de horário/capacidade.

---

## Sprint 10 — Atendimento e histórico

**Pré-requisito:** D04 fechada.

- Registro de atendimento conforme campos definidos em D04
- Histórico de atendimentos por pessoa, visível conforme RBAC

**Entrega:** ciclo completo cadastro → solicitação → elegibilidade → agendamento → atendimento → histórico funcionando de ponta a ponta.

---

## Sprint 11 — Frontend do MVP

Telas: login, dashboard, pessoas atendidas, cadastro de pessoa, serviços, solicitação de serviço, avaliação de elegibilidade (conforme papel), agenda, agendamento, atendimento, perfil, controle de usuários.

**Critério de saída da Sprint:** um funcionário real conseguiria operar o sistema usando só essas telas.

---

## Sprint 12 — Testes automatizados

- Testes unitários das regras de negócio (principalmente conflito de agenda/capacidade e regras de elegibilidade)
- Testes de integração API → banco
- Testes de autorização para cada papel
- Testes de concorrência no agendamento (dois usuários tentando o mesmo horário/vaga)

---

## Sprint 13 — Auditoria de segurança

Percorrer as regras de `SDP_SEGURANCA.md` uma por uma e testar cada uma. Incluir teste específico de **IDOR**: tentar acessar `/api/pessoas/101` estando autenticado como funcionário sem relação com a pessoa 101 — deve ser negado.

---

## Sprint 14 — Auditoria de dados e LGPD

- Validar logs de auditoria (quem fez o quê, quando, em qual registro — especialmente decisões de elegibilidade)
- Validar minimização de dados retornados pela API (cada papel recebe só o necessário)
- Validar backup e teste de restauração (T06) — backup nunca restaurado em teste não conta como estratégia de recuperação
- Confirmar que ambientes de desenvolvimento/homologação não usam dado real de pessoa atendida (T07)

---

## Sprint 15 — Testes de usabilidade

Alguém fora da equipe de desenvolvimento usa o sistema sem explicação prévia ("cadastre uma pessoa", "registre uma solicitação de serviço"). Se a pessoa não conseguir sem ajuda, é um problema de UX a corrigir antes da entrega.

---

## Sprint 16 — Testes de aceitação

Verificar cada requisito de negócio original contra o sistema real — por exemplo: "funcionário sem relação com a pessoa não acessa o cadastro dela" → testar diretamente.

---

## Sprint 17 — Testes de carga

Múltiplos usuários, múltiplos agendamentos simultâneos. Objetivo: descobrir se o sistema aguenta uso concorrente antes de expor isso ao instituto real.

---

## Sprint 18 — Homologação

Simular o fluxo completo do instituto: pessoa chega → funcionário cadastra → solicita serviço → elegibilidade avaliada → agendamento → atendimento → histórico.

---

## Sprint 19 — Deploy

Servidor em nuvem, banco de produção em rede privada (nunca exposto publicamente — T03), HTTPS, domínio, secrets em produção, backups automatizados, monitoramento, logs, plano de resposta a incidentes.

---

## Sprint 20 — Entrega

A entrega não é "está funcionando". A entrega inclui:

- **Produto** funcionando em ambiente real
- **Código** organizado no repositório, com Pull Requests revisados
- **Documentação** completa (`SDP_DOCUMENTACAO_PROJETO.md`, `SDP_DECISOES_PENDENTES.md` — já fechado, `SDP_API.md`, `SDP_SEGURANCA.md`, este roadmap)
- **Evidências**: testes, cobertura, decisões arquiteturais registradas
- **Apresentação**: demonstração ao vivo do fluxo login → permissão → pessoa → solicitação → elegibilidade → agendamento → atendimento → auditoria

---

## Divisão de trabalho sugerida (adaptar conforme tamanho real da equipe)

| Sprints | Foco |
|---|---|
| 1, 2 | Fechamento de decisões + banco |
| 6, 7 | Cadastro de pessoas + serviços |
| 8 | Elegibilidade (a mais dependente de decisão de negócio — reservar tempo extra) |
| 9, 10 | Agenda/agendamento + atendimento |
| 4, 5 | Autenticação + autorização |

A partir da Sprint 11 em diante, recomenda-se misturar quem trabalhou em partes diferentes do sistema para revisão cruzada de código — quem construiu elegibilidade revisa quem construiu agendamento, e vice-versa. Isso reduz o risco de uma única pessoa ser a única a entender uma parte crítica do sistema (especialmente elegibilidade, que é o módulo mais sensível a erro).