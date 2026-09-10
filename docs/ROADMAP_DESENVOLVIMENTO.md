# Roadmap de Desenvolvimento

> Ordem cronológica de construção do sistema, do levantamento de requisitos até a entrega. Ligado a `SDP_DOCUMENTACAO_PROJETO.md` e `SDP_DECISOES_PENDENTES.md`.
>
> ✅ **D01–D09 fechadas.** As Sprints abaixo foram atualizadas para refletir isso — não tratam mais essas decisões como pendências a resolver, e sim como schema/regra já implementados e testados.

## Regra de ouro da equipe

> Não avançamos para a próxima Sprint porque o prazo chegou. Avançamos quando o incremento atende aos critérios de aceitação definidos **e** está testado.

Nenhuma tarefa é considerada concluída só porque o código foi escrito. Ela precisa estar: **implementada + testada + integrada + revisada em Pull Request + documentada**.

## Visão geral das fases

```text
Requisitos → Decisões de negócio (D01-D09, fechadas) → Arquitetura → Banco de dados → Backend base →
Autenticação → Autorização → Pessoas → Serviços → Elegibilidade → Agenda/Fila de espera → Atendimento →
Central de Atendimento (Fase 1) → Frontend do MVP → Testes automatizados → Segurança → Auditoria/LGPD →
Usabilidade → Aceitação → Carga → Homologação → Deploy → Entrega
```

---

## Sprint 0 — Levantamento de requisitos ✅ Concluída

- Problema, objetivo e fluxo principal do negócio definidos
- Atores confirmados: administrador, recepcionista (D05: mesma pessoa cadastra e avalia elegibilidade)
- Requisitos funcionais e não funcionais levantados
- D01–D09 registradas e, ao longo do processo, todas fechadas

**Entrega:** `SDP_DOCUMENTACAO_PROJETO.md`, `REQUISITOS.md`, `SDP_DECISOES_PENDENTES.md`.

---

## Sprint 1 — Decisões de negócio + arquitetura ✅ Concluída

- D01 (elegibilidade geral por pessoa), D02 (organizações sem login), D03 (só administrador cria serviço), D04 (atendimento só compareceu/não compareceu), D05 (sem papel avaliador separado), D06 (RG/CPF sempre obrigatórios), D07 (pré-requisito: idade/escolaridade/CNH), D08 (fila de espera), D09 (profissional nunca loga) — todas fechadas e registradas com data
- RBAC simplificado para 2 papéis (`administrador`, `recepcionista`) — decisão técnica, ver ressalva em `REGRAS_NEGOCIO.md`, seção 4
- DER definitivo desenhado
- Central de Atendimento omnichannel incorporada à arquitetura (ver ressalva de proveniência em `REQUISITOS.md`, seção 9)

**Entrega:** `SDP_DOCUMENTACAO_PROJETO.md` e `SDP_DECISOES_PENDENTES.md` atualizados, DER definitivo, `ARQUITETURA.md` v2.

---

## Sprint 2 — Banco de dados ✅ Concluída (schema principal); Central de Atendimento pendente de merge no script executável

- Tabelas de autenticação: `usuarios`, `papeis`, `usuarios_papeis`, `sessoes`, `auditoria`
- Tabelas de negócio: `niveis_escolaridade`, `pessoas`, `correcoes_cadastrais`, `avaliacoes_elegibilidade`, `organizacoes`, `servicos`, `solicitacoes_servico`, `agenda_datas`, `agendamentos`, `fila_espera`, `atendimentos`
- Função `alocar_atendimento()` (capacidade decidida por transação, `FOR UPDATE`) e triggers de imutabilidade/status
- Separação `db_owner`/`app_runtime` (T04), com `REVOKE` testado
- 12 testes funcionais executados contra PostgreSQL 16 real — todos passaram

**Pendente antes de fechar esta Sprint de vez:**
- Tabelas da Central de Atendimento (`canais`, `conversas`, `mensagens`, `solicitacoes`) já estão em `BANCO_DADOS.md`, mas ainda não foram mergeadas em `db/init/db_init.sql` — ver `BANCO_DADOS.md`, seção 8, item 4
- 4 testes novos (13–16) relacionados à Central de Atendimento ainda não executados

**Entrega:** banco funcional e validado por teste manual — schema principal completo; Central de Atendimento aguardando merge.

---

## Sprint 3 — Backend base ⚠️ Iniciada com dívida técnica registrada

- Estrutura do projeto (FastAPI), conexão com o banco, ORM
- Tratamento de erros padronizado, validação de entrada
- Logs de aplicação
- `GET /health` (observabilidade mínima — T08)

**Dívida técnica conhecida:** o módulo de autenticação já implementado usa o RBAC antigo (5 papéis: administrador, gestor, funcionario, avaliador, auditor). Precisa de migration para o RBAC final (`administrador`, `recepcionista`) antes de qualquer dado real — ver `BANCO_DADOS.md`, seção 7.

---

## Sprint 4 — Autenticação ✅ Concluída (aguardando migration de RBAC — ver Sprint 3)

- Login, logout real com revogação de sessão, hash de senha
- Sessão via cookie `HttpOnly`/`Secure`/`SameSite=Strict`
- Rate limiting em tentativas de login

**Testar:** senha correta → acesso; senha errada → bloqueio; sessão expirada → acesso negado; logout → sessão revogada no servidor.

---

## Sprint 5 — Autorização (RBAC)

**Bloqueada até a migration da Sprint 3 ser feita.** Implementar os 2 papéis definitivos (`REGRAS_NEGOCIO.md`, seção 4); middleware de autorização no backend, nunca no frontend; testar diretamente na API (ex.: recepcionista tentando acessar `/api/auditoria` deve receber `403`).

---

## Sprint 6 — Cadastro de pessoas atendidas

Formulário de cadastro, consulta, edição, inativação, correção cadastral auditada — campos definitivos de `BANCO_DADOS.md`, seção 4.3. Testes: CPF duplicado → negado; `UPDATE` direto em campo protegido → negado (trigger); Mass Assignment bloqueado.

---

## Sprint 7 — Serviços e organizações parceiras

Catálogo de serviços (escrita só administrador — D03); cadastro de organizações (sem login — D02); geração de PDF de encaminhamento (RF11).

---

## Sprint 8 — Elegibilidade

Fluxo de avaliação geral por pessoa (D01); registro somente-inserção; view de decisão vigente; auditoria de toda decisão.

---

## Sprint 9 — Agenda, agendamento e fila de espera

Cadastro de data + capacidade por serviço (D09: sempre em nome do profissional, sem login dele); função `alocar_atendimento()` chamada pela API; teste de concorrência (duas solicitações simultâneas disputando a última vaga).

---

## Sprint 10 — Atendimento e histórico

Registro `compareceu`/`não compareceu` (D04); trigger atualizando status do agendamento automaticamente; histórico por pessoa, visível conforme RBAC.

**Entrega:** ciclo completo cadastro → solicitação → elegibilidade → agendamento → atendimento → histórico funcionando de ponta a ponta.

---

## Sprint 10.5 — Central de Atendimento omnichannel, Fase 1 (NOVA)

> ⚠️ Ver `REQUISITOS.md`, seção 9 — este requisito ainda não tem decisão D0x formalmente registrada. Recomenda-se resolver isso antes ou durante esta Sprint, não depois.

- Merge das tabelas `canais`/`conversas`/`mensagens`/`solicitacoes` em `db/init/db_init.sql`
- Endpoints de `POST /api/conversas`, `POST /api/conversas/{id}/mensagens`, `POST /api/solicitacoes` (ver `API.md`)
- Registro **manual** do canal de origem pela recepcionista — sem integração de API externa nesta fase
- Testes 13–16 de `BANCO_DADOS.md`, seção 6

**Entrega:** Central de Atendimento operando manualmente, com auditoria completa de conversa e mensagem.

---

## Sprint 11 — Frontend do MVP

Telas: login, dashboard, pessoas atendidas, cadastro/correção de pessoa, serviços, solicitação de serviço, elegibilidade, agenda, agendamento, atendimento, central de atendimento (conversas/mensagens), perfil, controle de usuários.

**Critério de saída:** uma recepcionista real conseguiria operar o sistema usando só essas telas.

---

## Sprint 12 — Testes automatizados

Testes unitários das regras de negócio (pré-requisito de serviço, capacidade/fila, elegibilidade); testes de integração API → banco; testes de autorização por papel; testes de concorrência no agendamento.

---

## Sprint 13 — Auditoria de segurança

Percorrer as regras de `SEGURANCA.md` uma por uma e testar cada uma. Teste específico de IDOR obrigatório.

---

## Sprint 14 — Auditoria de dados e LGPD

Validar logs de auditoria; validar minimização de dados retornados pela API; validar backup e teste de restauração (T06); confirmar que ambientes de desenvolvimento/homologação não usam dado real de pessoa atendida (T07).

---

## Sprint 15 — Testes de usabilidade

Alguém fora da equipe usa o sistema sem explicação prévia.

---

## Sprint 16 — Testes de aceitação

Verificar cada requisito de negócio original contra o sistema real.

---

## Sprint 17 — Testes de carga

Múltiplos usuários, múltiplas solicitações simultâneas disputando capacidade.

---

## Sprint 18 — Homologação

Simular o fluxo completo do instituto, incluindo um contato chegando pela Central de Atendimento até o atendimento concluído.

---

## Sprint 19 — Deploy

Servidor em nuvem, banco de produção em rede privada (T03), HTTPS, domínio, secrets em produção, backups automatizados, monitoramento, plano de resposta a incidentes.

> A partir desta Sprint, se a Fase 2 da Central de Atendimento (webhooks) estiver em andamento, os endpoints de webhook precisam estar alcançáveis pela internet via HTTPS — sem expor o banco.

---

## Sprint 20 — Entrega

- **Produto** funcionando em ambiente real
- **Código** organizado no repositório, com Pull Requests revisados
- **Documentação** completa e sincronizada (todos os documentos em `docs/`)
- **Evidências**: testes, cobertura, decisões arquiteturais registradas
- **Apresentação**: demonstração ao vivo do fluxo completo, incluindo Central de Atendimento

---

## Divisão de trabalho sugerida

| Sprints | Foco |
|---|---|
| 2, 3 | Banco de dados + backend base (inclui migration de RBAC) |
| 6, 7 | Cadastro de pessoas + serviços/organizações |
| 8 | Elegibilidade |
| 9, 10 | Agenda/fila de espera + atendimento |
| 10.5 | Central de Atendimento (Fase 1) |
| 4, 5 | Autenticação + autorização |

A partir da Sprint 11 em diante, recomenda-se revisão cruzada de código entre quem trabalhou em partes diferentes do sistema, especialmente elegibilidade (módulo mais sensível a erro de negócio).