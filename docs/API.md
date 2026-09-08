# API — Documentação de Endpoints

> Adaptado de um projeto de referência (clínica odontológica). Endpoints marcados com ❓ dependem de decisões ainda pendentes em `SDP_DECISOES_PENDENTES.md` e não devem ser implementados como definitivos até essas decisões fecharem.

API REST, formato JSON. **Autenticação via sessão de servidor** (cookie `HttpOnly` + `Secure` + `SameSite=Strict`) — ver `SDP_DOCUMENTACAO_PROJETO.md`, seção 3.5. Todo endpoint exige autenticação, exceto `/auth/login`. Toda autorização por papel segue a tabela RBAC de `SDP_DOCUMENTACAO_PROJETO.md` seção 4.2 e é verificada no Backend, nunca só no Frontend.

## Convenção de códigos HTTP usados no projeto

| Código | Significado | Quando usar |
|---|---|---|
| 200 | OK | Leitura ou alteração bem-sucedida |
| 201 | Created | Recurso criado com sucesso |
| 400 | Bad Request | Requisição malformada |
| 401 | Unauthorized | Não autenticado ou sessão inválida/expirada |
| 403 | Forbidden | Autenticado, mas sem permissão para essa ação (RBAC) |
| 404 | Not Found | Recurso não existe |
| 409 | Conflict | Conflito de regra de negócio (ex.: horário/capacidade sobreposta) |
| 422 | Unprocessable Content | Dado bem formado, mas inválido pela regra de negócio |
| 429 | Too Many Requests | Rate limiting acionado |
| 500 | Internal Server Error | Falha não tratada — deve virar log de auditoria/erro, nunca expõe stack trace ao cliente |
| 503 | Service Unavailable | Dependência indisponível |

## Autenticação

### `POST /api/auth/login`
Request:
```json
{ "email": "funcionario@instituto.org", "senha": "..." }
```
Response `200` — cria sessão, devolve cookie `HttpOnly`/`Secure`/`SameSite=Strict` com o identificador de sessão; corpo da resposta traz só o necessário para a interface:
```json
{ "usuario_id": 7, "papeis": ["funcionario"] }
```
Response `401`: credenciais inválidas. Response `429`: rate limit de tentativas de login acionado.

### `POST /api/auth/logout`
Revoga a sessão atual no servidor (não apenas expira o cookie no cliente — ver tabela `sessoes` em `SDP_DOCUMENTACAO_PROJETO.md` seção 6.2). Response `200`.

## Pessoas atendidas

> Campos exatos do cadastro dependem de D06 (`SDP_DECISOES_PENDENTES.md`) — os campos abaixo são um mínimo plausível de contato/identificação, não a lista definitiva.

### `GET /api/pessoas`
Papéis: funcionário (todos), gestor (leitura), auditor (leitura). Filtros: `?nome=`, `?documento=`, `?ativo=`.

### `POST /api/pessoas`
Papel: funcionário.
Request (❓ campos sujeitos a D06):
```json
{
  "nome": "Maria Silva",
  "documento": "12345678900",
  "telefone": "21999990000",
  "email": "maria@email.com",
  "endereco": "Rua X, 100"
}
```
Response `201`: pessoa criada. Response `409`: documento já cadastrado (se documento for exigido — depende de D06).

### `GET /api/pessoas/{id}`
Response `404` se não existir; `403` se o papel não tiver permissão sobre o recurso.

### `PUT /api/pessoas/{id}`
Papel: funcionário. Campos alteráveis definidos explicitamente por operação (proteção contra Mass Assignment — regra 12 de `SDP_SEGURANCA.md`); qualquer campo fora da lista permitida é ignorado e a tentativa é registrada em auditoria.

## Funcionários e papéis

### `GET /api/funcionarios` · `POST /api/funcionarios` · `GET /api/funcionarios/{id}`
Papel de escrita: administrador. Campos: `usuario_id`, `papeis` (um ou mais, conforme RBAC).

## Organizações ❓

> Depende de D02. Se o instituto confirmar que existe só uma organização (o próprio instituto), esta seção inteira não é implementada na v1 — o instituto é um valor fixo, não uma entidade com CRUD.

### `GET /api/organizacoes` · `POST /api/organizacoes`
Papel de escrita: administrador. **Placeholder — não implementar antes de D02 fechar.**

## Serviços

### `GET /api/servicos` · `POST /api/servicos` · `PUT /api/servicos/{id}`
Papel de escrita: administrador (ver D03 — pode mudar se o instituto quiser descentralizar a criação de serviços). Campos: `nome`, `descricao`, `organizacao_id` (se D02 confirmar múltiplas organizações), `capacidade`, `disponibilidade`, `requer_avaliacao_elegibilidade`.

## Solicitações de serviço

### `POST /api/solicitacoes-servico`
Papel: funcionário. Registra que uma pessoa solicitou (ou foi encaminhada a) um serviço.
Request:
```json
{
  "pessoa_id": 12,
  "servico_id": 3
}
```
Response `201`. Se `servico.requer_avaliacao_elegibilidade = true`, o status inicial da solicitação é `aguardando_avaliacao`; caso contrário, `apta_para_agendamento`.

### `GET /api/solicitacoes-servico/{id}`
Retorna status da solicitação — nunca a decisão detalhada de elegibilidade junto (endpoint separado, com permissão separada).

## Elegibilidade ❓

> Contrato **provisório** — a estrutura definitiva depende de D01 (modelo geral vs. por serviço vs. híbrido). Implementar isso antes de D01 fechar arrisca reescrever o módulo inteiro depois.

### `POST /api/elegibilidade/avaliar`
Papel: avaliador (ou funcionário, se D05 confirmar que não existe papel separado).
Request:
```json
{
  "solicitacao_servico_id": 45,
  "decisao": "elegivel",
  "criterios_utilizados": "...",
  "justificativa": "..."
}
```
`decisao` aceita: `elegivel`, `nao_elegivel`, `necessita_revisao`. Toda chamada gera registro de auditoria com responsável, data e critério — nunca é aceita sem justificativa quando a decisão é `nao_elegivel` ou `necessita_revisao`.

### `GET /api/elegibilidade/{solicitacao_servico_id}`
Papéis: administrador, gestor (leitura), avaliador, auditor (leitura). Funcionário só vê o resultado (`elegivel`/`nao_elegivel`/`em_avaliacao`), não necessariamente o critério/justificativa completos — a granularidade exata depende de D01.

## Agenda

### `GET /api/agenda?funcionario_id={id}&data={YYYY-MM-DD}`
Papéis: funcionário (a própria agenda e, se aplicável, agenda de serviços que atende), gestor (leitura, qualquer), administrador (qualquer).
Response `200`:
```json
{
  "funcionario_id": 3,
  "data": "2026-09-08",
  "horarios": [
    { "inicio": "08:00", "fim": "08:30", "status": "livre" },
    { "inicio": "08:30", "fim": "09:00", "status": "ocupado", "agendamento_id": 55 }
  ]
}
```

## Agendamentos

### `POST /api/agendamentos`
Papel: funcionário.
Request:
```json
{
  "solicitacao_servico_id": 45,
  "funcionario_id": 3,
  "data": "2026-09-08",
  "hora_inicio": "09:00"
}
```
Recusado com `409` se a solicitação não estiver com status `apta_para_agendamento`. `hora_fim` é calculada no servidor a partir da duração do serviço — nunca aceita do cliente. Response `201` em sucesso; `409` se o horário/capacidade já estiver ocupado (o Backend recebe o erro da constraint do banco e traduz para uma resposta clara).

### `PATCH /api/agendamentos/{id}/cancelar`
Papéis: funcionário, administrador.

### `GET /api/agendamentos/{id}`
Retorna status e dados do agendamento.

## Atendimentos ❓

> Estrutura de campos depende de D04 — o exemplo abaixo é um mínimo genérico.

### `POST /api/atendimentos`
Papel: funcionário.
Request (❓ campos sujeitos a D04):
```json
{
  "agendamento_id": 55,
  "compareceu": true,
  "observacoes": "..."
}
```
Response `201`. Marca o agendamento correspondente como `concluido`.

### `GET /api/atendimentos/{pessoa_id}`
Histórico de atendimentos de uma pessoa. Papéis: funcionário, gestor (leitura), auditor (leitura).

## Auditoria (somente leitura)

### `GET /api/auditoria?tabela=&registro_id=&usuario_id=`
Papel: auditor, gestor (leitura). Nenhum papel tem permissão de escrita direta nesta rota — os registros são gerados automaticamente pelo Backend a cada operação sensível (login, decisão de elegibilidade, alteração cadastral, agendamento, cancelamento).