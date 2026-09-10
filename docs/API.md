# API — Documentação de Endpoints

> ✅ D01–D09 fechadas. Este documento reflete o schema real de `BANCO_DADOS.md` — não o rascunho anterior. Se algo aqui divergir do banco, o banco vale.

API REST, formato JSON. **Autenticação via sessão de servidor** (cookie `HttpOnly` + `Secure` + `SameSite=Strict`). Todo endpoint exige autenticação, exceto `/api/auth/login` e, a partir da Fase 2 da Central de Atendimento, os endpoints de webhook (que usam verificação de assinatura do provedor no lugar de sessão — ver `ARQUITETURA.md`, seção 2.1). Toda autorização por papel segue a tabela RBAC de `REGRAS_NEGOCIO.md`, seção 4, e é verificada no Backend, nunca só no Frontend.

## Convenção de códigos HTTP

| Código | Significado | Quando usar |
|---|---|---|
| 200 | OK | Leitura ou alteração bem-sucedida |
| 201 | Created | Recurso criado com sucesso |
| 400 | Bad Request | Requisição malformada |
| 401 | Unauthorized | Não autenticado ou sessão inválida/expirada |
| 403 | Forbidden | Autenticado, mas sem permissão para essa ação (RBAC) |
| 404 | Not Found | Recurso não existe |
| 409 | Conflict | Conflito de regra de negócio |
| 422 | Unprocessable Content | Dado bem formado, mas inválido pela regra de negócio |
| 429 | Too Many Requests | Rate limiting acionado |
| 500 | Internal Server Error | Falha não tratada — vira log de auditoria/erro, nunca expõe stack trace |
| 503 | Service Unavailable | Dependência indisponível |

## Autenticação

### `POST /api/auth/login`
```json
{ "email": "recepcionista@instituto.org", "senha": "..." }
```
Response `200` — cria sessão, devolve cookie `HttpOnly`/`Secure`/`SameSite=Strict`:
```json
{ "usuario_id": 7, "papeis": ["recepcionista"] }
```
Response `401`: credenciais inválidas. Response `429`: rate limit de login acionado.

### `POST /api/auth/logout`
Revoga a sessão atual no servidor (`sessoes.revogado_em`), não apenas expira o cookie no cliente. Response `200`.

## Usuários e papéis

> Corrigido em relação à versão anterior: não existe entidade `funcionarios` no schema — usuários do sistema são `usuarios` + `usuarios_papeis`, com 2 papéis possíveis (`administrador`, `recepcionista`).

### `GET /api/usuarios` · `POST /api/usuarios` · `GET /api/usuarios/{id}`
Papel de escrita: administrador. Campos: `nome`, `email`, `senha` (na criação), `papeis` (um ou mais).

### `PATCH /api/usuarios/{id}/desativar`
Papel: administrador. Marca `ativo = false` e revoga todas as sessões ativas do usuário — nunca `DELETE`.

## Pessoas atendidas

> Campos definitivos, D06 fechada — RG e CPF sempre obrigatórios.

### `GET /api/pessoas`
Papéis: administrador (leitura), recepcionista (leitura/escrita). Filtros: `?nome=`, `?cpf=`, `?ativo=`.

### `POST /api/pessoas`
Papel: recepcionista.
```json
{
  "nome": "Maria Silva",
  "rg": "1234567",
  "cpf": "12345678900",
  "data_nascimento": "1990-04-12",
  "telefone": "21999990000",
  "email": "maria@email.com",
  "cep": "20000000",
  "logradouro": "Rua X",
  "numero": "100",
  "bairro": "Centro",
  "cidade": "Rio de Janeiro",
  "uf": "RJ",
  "escolaridade_id": 4,
  "possui_cnh": false
}
```
Response `201`. Response `409`: CPF já cadastrado. `endereco` é preenchido automaticamente a partir do `cep` via API ViaCEP no Frontend, mas o Backend valida de novo antes de gravar (nunca confia só no que o cliente enviou).

### `GET /api/pessoas/{id}`
Response `404` se não existir; `403` se o papel não tiver permissão.

### `PUT /api/pessoas/{id}`
Papel: recepcionista. Aceita apenas campos editáveis (telefone, e-mail, endereço, título de eleitor, escolaridade, CNH). `nome`, `rg`, `cpf`, `data_nascimento` são **rejeitados explicitamente** — tentativa registrada em auditoria; correção real passa por `POST /api/pessoas/{id}/correcoes-cadastrais`.

### `POST /api/pessoas/{id}/correcoes-cadastrais`
Papel: recepcionista (solicita), administrador (aprova — `aprovado_por`). Corrige `nome`/`rg`/`cpf`/`data_nascimento` com justificativa, fora do fluxo normal de `PUT`.

## Elegibilidade

> Corrigido em relação à versão anterior: elegibilidade é **geral por pessoa** (D01), não por solicitação de serviço — o endpoint recebe `pessoa_id`, não `solicitacao_servico_id`.

### `POST /api/elegibilidade/avaliar`
Papel: recepcionista.
```json
{
  "pessoa_id": 12,
  "decisao": "elegivel",
  "recebe_beneficio_governo": true,
  "participa_projeto_social": false,
  "renda_familiar": 1800.00,
  "justificativa": "..."
}
```
`decisao` aceita: `elegivel`, `nao_elegivel`, `em_avaliacao`, `necessita_revisao`. Cada chamada é um novo registro (somente-inserção) — nunca edita uma avaliação anterior. Gera auditoria com responsável, data e critério.

### `GET /api/elegibilidade/{pessoa_id}`
Retorna a decisão **vigente** (a mais recente) e, opcionalmente, `?historico=true` para todas as avaliações já feitas. Papéis: administrador, recepcionista.

## Serviços

### `GET /api/servicos` · `POST /api/servicos` · `PUT /api/servicos/{id}`
Papel de escrita: **administrador** (D03 — recepcionista só lê). Campos: `nome`, `descricao`, `organizacao_id` (opcional), `idade_minima` (opcional), `escolaridade_minima_id` (opcional), `requer_cnh` (opcional). "Excluir" um serviço é `PUT` com `ativo = false` — nunca `DELETE` físico, para não quebrar histórico de solicitações antigas.

## Organizações parceiras

> D02 fechada: organizações existem (parceiros externos, ex.: advogado), mas **nunca têm login nem acesso ao sistema**.

### `GET /api/organizacoes` · `POST /api/organizacoes`
Papel de escrita: administrador. Campos: `nome`, `tipo_contato`.

### `GET /api/pessoas/{id}/encaminhamento.pdf`
RF11. Papéis: administrador, recepcionista. Gera PDF com dados pertinentes da pessoa para entregar a uma organização parceira — nunca dá acesso direto ao sistema para o parceiro.

## Solicitações de serviço

### `POST /api/solicitacoes-servico`
Papel: recepcionista. Registra que uma pessoa solicitou um serviço; o Backend calcula automaticamente o pré-requisito (idade/escolaridade/CNH) e grava o snapshot usado na decisão.
```json
{ "pessoa_id": 12, "servico_id": 3 }
```
Response `201`:
```json
{
  "id": 45,
  "status": "apta_para_agendamento",
  "prerequisito_atendido": true
}
```
Se `prerequisito_atendido = false`, `status` já vem como `bloqueada_por_prerequisito` — a checagem acontece no `INSERT`, não depois.

### `GET /api/solicitacoes-servico/{id}`
Retorna status e snapshot do pré-requisito checado no momento da solicitação.

## Agenda

> Corrigido em relação à versão anterior: agenda é por **serviço + data**, não por funcionário (D09 — o profissional nunca loga; a Recepcionista cadastra a data em nome dele).

### `GET /api/agenda?servico_id={id}&data={YYYY-MM-DD}`
Papéis: administrador (leitura), recepcionista (leitura/escrita).
```json
{
  "servico_id": 3,
  "data": "2026-09-08",
  "capacidade": 4,
  "ocupados": 3,
  "vagas_livres": 1
}
```

### `POST /api/agenda`
Papel: recepcionista. Cria uma data de agenda para um serviço.
```json
{
  "servico_id": 3,
  "responsavel_usuario_id": null,
  "data": "2026-09-08",
  "capacidade": 4
}
```
`responsavel_usuario_id` é referência informativa opcional — nunca exige login do profissional. Response `409` se já existir uma data para esse serviço nessa data (`UNIQUE(servico_id, data)`).

## Agendamentos e fila de espera

> Corrigido: o corpo do `POST` não inclui mais `funcionario_id`/`hora_inicio` — a alocação é por `agenda_data_id` inteiro (data com capacidade), via a função `alocar_atendimento()`.

### `POST /api/agendamentos`
Papel: recepcionista. Recusado com `422` se a solicitação não estiver com status `apta_para_agendamento`.
```json
{ "solicitacao_servico_id": 45, "agenda_data_id": 9 }
```
Response `201`, corpo indica o resultado real da alocação (nunca é erro — fila de espera é fluxo normal):
```json
{ "resultado": "agendado", "agendamento_id": 101 }
```
ou
```json
{ "resultado": "fila_espera", "fila_espera_id": 7 }
```

### `PATCH /api/agendamentos/{id}/cancelar`
Papéis: recepcionista, administrador.

### `GET /api/agendamentos/{id}`
Retorna status e dados do agendamento.

## Atendimentos

> Corrigido: D04 fechou **só `compareceu`/`não compareceu`** — sem campo de observação livre.

### `POST /api/atendimentos`
Papel: recepcionista.
```json
{ "agendamento_id": 55, "compareceu": true }
```
Response `201`. Marca o agendamento correspondente como `concluido` (se `compareceu = true`) ou `nao_compareceu` — automaticamente, via trigger de banco, não lógica duplicada na aplicação.

### `GET /api/atendimentos/{pessoa_id}`
Histórico de atendimentos de uma pessoa. Papéis: administrador (leitura), recepcionista.

## Central de Atendimento omnichannel — Fase 1

> ⚠️ Sem decisão D0x rastreável — ver `REQUISITOS.md`, seção 9. Endpoints abaixo refletem a Fase 1 (registro manual do canal); endpoints de webhook (Fase 2) ainda não estão contratados aqui.

### `GET /api/canais`
Lista os canais disponíveis (presencial, telefone, whatsapp, e-mail, instagram, facebook, tiktok, site).

### `POST /api/conversas`
Papel: recepcionista. Abre uma conversa a partir de um contato — `pessoa_id` pode ser omitido se a pessoa ainda não foi identificada.
```json
{ "canal_id": 3, "pessoa_id": null }
```
Response `201`.

### `PATCH /api/conversas/{id}/identificar`
Papel: recepcionista. Vincula uma pessoa (existente ou recém-cadastrada) a uma conversa já aberta.
```json
{ "pessoa_id": 12 }
```

### `POST /api/conversas/{id}/mensagens`
Papel: recepcionista (mensagens do tipo `atendente`; mensagens do tipo `pessoa` são registradas manualmente na Fase 1, representando o que a pessoa disse pelo canal).
```json
{ "remetente_tipo": "pessoa", "conteudo": "Gostaria de saber sobre atendimento jurídico" }
```
Response `201`. **Mensagens não podem ser editadas nem excluídas** após criadas (append-only, mesmo princípio da auditoria).

### `GET /api/conversas/{id}/mensagens`
Histórico completo da conversa, em ordem cronológica.

### `POST /api/solicitacoes`
Papel: recepcionista. Abre um ticket a partir de uma conversa.
```json
{
  "conversa_id": 8,
  "pessoa_id": 12,
  "tipo": "agendamento",
  "solicitacao_servico_id": 45
}
```
`solicitacao_servico_id` é **obrigatório** quando `tipo = "agendamento"` (`422` se ausente — mesma regra do `CHECK` no banco).

### `PATCH /api/solicitacoes/{id}`
Papel: recepcionista. Atualiza `status` (`em_andamento`, `concluida`, `cancelada`) e `responsavel_id`.

## Auditoria (somente leitura)

### `GET /api/auditoria?tabela=&registro_id=&usuario_id=`
Papel: administrador. Nenhum papel tem permissão de escrita direta nesta rota — os registros são gerados automaticamente pelo Backend a cada operação sensível.