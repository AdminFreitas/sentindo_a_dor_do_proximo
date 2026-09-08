# Decisões Pendentes — Sentindo a Dor do Próximo

> Este documento existe para que nenhuma decisão importante seja **presumida** silenciosamente dentro do código. Está dividido em duas partes:
>
> - **Parte A — Decisões de negócio.** Só o instituto pode responder. Eu não devo, e a equipe técnica não deve, inventar critério de elegibilidade, estrutura organizacional ou regra de atendimento de um instituto que não é nosso.
> - **Parte B — Decisões técnicas.** Eu já apresento uma recomendação com justificativa em cada uma, mas ainda precisam de aprovação formal antes de virarem código — especialmente porque isso vai para um cliente real.
>
> **Nenhum item aqui deve ser considerado resolvido só por estar documentado.** Ele só é resolvido quando: (1) alguém com autoridade sobre o projeto decide, (2) a decisão é registrada, (3) vira código, (4) vira teste, (5) tem evidência de que funciona.

---

## Parte A — Decisões de negócio (só o instituto responde)

### D01 — Modelo de elegibilidade 🔴 Bloqueia o desenho do banco de dados

**A pergunta:** a pessoa tem uma elegibilidade **geral** perante o instituto (uma avaliação social que abre acesso a qualquer serviço), ou a elegibilidade é **por serviço** (cada solicitação passa por sua própria avaliação, com critérios possivelmente diferentes por tipo de serviço)?

**Por que importa:** essa é a decisão de maior impacto estrutural no banco de dados. Um modelo geral aponta para uma tabela `elegibilidade` ligada à pessoa; um modelo por serviço aponta para uma tabela ligada à `solicitacao_servico`; um modelo híbrido precisa das duas, com regra de precedência entre elas.

**Perguntas que ajudam a responder:**
- Hoje, na prática (sem sistema), uma pessoa "aprovada" para um curso automaticamente teria acesso a atendimento jurídico também, ou cada serviço é avaliado de novo?
- Existe uma "ficha social" única da pessoa, feita uma vez, que várias áreas do instituto consultam?
- Serviços diferentes (consulta, curso, jurídico) hoje usam os mesmos critérios de "quem precisa mais" ou critérios totalmente diferentes?

**Não decidir isso antes do banco gera:** retrabalho de migração real depois que o sistema já estiver em uso, com dado de pessoa real dentro — o pior momento possível para redesenhar uma tabela central.

---

### D02 — Organizações 🔴 Bloqueia parte do modelo de dados e do RBAC

**A pergunta:** existe só o instituto principal, ou há (ou haverá em breve) organizações parceiras que também oferecem serviços dentro do mesmo sistema?

**Se a resposta for "só o instituto por enquanto":** simplifica bastante — não precisa da entidade `organizacoes` na v1, só um campo fixo.

**Se a resposta for "sim, parceiros":** precisa decidir também:
- Um funcionário pertence a uma organização específica, ou pode atuar em várias?
- Uma organização parceira só oferece serviço, ou também tem acesso ao sistema para gerenciar sua própria agenda?
- Dados de pessoas atendidas são visíveis entre organizações parceiras, ou cada uma só vê o que atende diretamente?

**Recomendação enquanto não decidido:** modelar já pensando em múltiplas organizações no design conceitual (para não fechar a porta), mas **implementar só o instituto único na v1** — não construir a complexidade de organizações parceiras sem necessidade confirmada agora.

---

### D03 — Governança do catálogo de serviços 🟠 Bloqueia RF04 em detalhe

**A pergunta:** quem, na prática, decide criar um novo serviço, definir sua capacidade e disponibilidade? Só administração central, ou cada área/organização gerencia os próprios serviços?

**Isso define:** se "criar serviço" é uma permissão só de Administrador (como está na recomendação atual da seção 4.2) ou se precisa de um nível intermediário.

---

### D04 — O que realmente é registrado no atendimento 🟠 Bloqueia RF07 em detalhe

**A pergunta:** ao concluir um atendimento, o que o funcionário registra? Exemplos possíveis: só "compareceu/não compareceu"; um resumo textual livre; campos estruturados específicos por tipo de serviço (ex.: um curso registra frequência, uma consulta registra encaminhamento).

**Por que importa:** se cada tipo de serviço tem um registro de atendimento muito diferente, isso pode significar uma estrutura de "atendimento" com campos extensíveis por tipo de serviço, não uma tabela única rígida.

---

### D05 — Existe o papel "Avaliador" na operação real? 🟠 Bloqueia RBAC definitivo

**A pergunta:** no dia a dia do instituto, a pessoa que atende/cadastra é a mesma que decide elegibilidade, ou é uma função separada (ex.: assistente social)?

**Se for a mesma pessoa:** o papel "Avaliador" da seção 4.2 não deveria existir separado — as permissões de elegibilidade vão para "Funcionário".
**Se for função separada:** mantemos "Avaliador" como papel próprio, com RBAC restrito (só avalia, não agenda).

---

### D06 — Campos mínimos de cadastro da pessoa atendida 🟡 Bloqueia RF02 em detalhe

**A pergunta:** quais dados o instituto realmente precisa coletar no cadastro? Nome, contato, e o quê mais? Documento de identificação é obrigatório sempre, ou depende do serviço?

**Por que importa (minimização de dados, seção 5.2):** cada campo a mais é um campo a proteger, auditar e eventualmente expor a risco de vazamento. A lista definitiva deve vir de necessidade real do instituto, não de "padrão de mercado" — evitar copiar cegamente campos de outro tipo de sistema (ex.: campos de prontuário de saúde, que só fazem sentido se um dos serviços for da área da saúde).

---

## Parte B — Decisões técnicas (recomendação já dada, precisa de aprovação)

### T01 — Stack de backend 🟠

**Recomendação:** FastAPI (Python). **Alternativa aceitável:** qualquer stack que a equipe já domine — a arquitetura em módulos (seção 3.4) não depende de framework específico.
**Aprovar/ajustar:** ______________________

### T02 — Estratégia de autenticação 🔴

**Recomendação:** sessões controladas pelo servidor, cookie `HttpOnly/Secure/SameSite=Strict`, tabela de sessões no banco para permitir logout/revogação reais (seção 3.5 e 6.2 já têm o rascunho de tabela `sessoes`).
**Por que é crítico:** esta foi exatamente a decisão que ficou ambígua e gerou um problema de segurança real em outro projeto de referência — aqui já nasce explícita para não repetir o erro.
**Aprovar/ajustar:** ______________________

### T03 — Hospedagem 🟠

**Recomendação:** nuvem, com banco em rede privada, nunca exposto publicamente à internet.
**Aprovar/ajustar:** ______________________

### T04 — Separação de usuários do PostgreSQL por privilégio 🔴

**Recomendação:** usuário de migração/owner separado do usuário de execução da aplicação (`app_runtime`), com `UPDATE/DELETE` revogado explicitamente em `auditoria` (e futuramente em qualquer tabela que deva ser append-only). Testar de fato que o `REVOKE` funciona antes de confiar nele — não basta declarar a intenção.
**Aprovar/ajustar:** ______________________

### T05 — Criptografia de dados sensíveis em repouso 🔴

**Ainda em aberto:** onde (coluna vs. disco), como (`pgcrypto` vs. aplicação vs. KMS do provedor de nuvem) e quem gerencia a chave. Não deve ficar apenas como "os dados devem ser criptografados" sem essas três respostas — isso não é implementável nem verificável do jeito que está.
**Aprovar/ajustar:** ______________________

### T06 — Backup e Disaster Recovery 🔴

**Falta definir:** RPO (quanto dado o instituto aceita perder), RTO (quanto tempo pode ficar fora do ar), frequência, retenção, criptografia do backup, e teste real de restauração periódico (não só a intenção documentada).
**Aprovar/ajustar:** ______________________

### T07 — Ambientes separados e dados sintéticos fora de produção 🔴

**Recomendação:** DEV / homologação / produção com bancos e secrets próprios. **Proibição explícita de usar dado real de pessoa atendida fora de produção**, mesmo em teste interno da equipe.
**Aprovar/ajustar:** ______________________

### T08 — Observabilidade mínima 🟠

**Recomendação:** `GET /health`, log de erros 5xx, alertas mínimos (backup falhou, banco indisponível, taxa de falha de login anormal).
**Aprovar/ajustar:** ______________________

### T09 — CI/CD e política de dependências 🟡

**Recomendação:** pipeline com lint → testes → scan de dependências → build antes de qualquer merge em produção.
**Aprovar/ajustar:** ______________________

---

## Como fechar este documento

| Decisão | Quem responde | Status |
|---|---|---|
| D01 — Modelo de elegibilidade | Instituto | Pendente |
| D02 — Organizações | Instituto | Pendente |
| D03 — Governança do catálogo de serviços | Instituto | Pendente |
| D04 — Registro de atendimento | Instituto | Pendente |
| D05 — Papel Avaliador existe? | Instituto | Pendente |
| D06 — Campos do cadastro da pessoa | Instituto | Pendente |
| T01–T09 | Equipe técnica | Pendente |

**Ordem recomendada:** D01, D02 e D05 primeiro — elas mudam a estrutura do banco e do RBAC. D03, D04 e D06 podem ser fechadas em paralelo com o início da Sprint 1. As decisões técnicas (T01–T09) podem avançar em paralelo, mas T02, T04, T05, T06 e T07 (todas 🔴) não devem ficar em aberto além da Sprint 2 do roadmap.

Assim que uma decisão for tomada, ela deve ser removida deste documento e:
1. Refletida na seção correspondente de `SDP_DOCUMENTACAO_PROJETO.md`;
2. Registrada (idealmente como ADR, se técnica);
3. Transformada em requisito verificável, não apenas em texto.
