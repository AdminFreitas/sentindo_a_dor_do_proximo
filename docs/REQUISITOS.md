# Requisitos do Projeto — Sentindo a Dor do Próximo

> Este documento detalha os requisitos já apresentados em `SDP_DOCUMENTACAO_PROJETO.md` (seções 1 e 2), no mesmo formato usado como referência estrutural em outros projetos. Os selos ✅/🔧/❓ seguem a mesma convenção: ✅ confirmado, 🔧 recomendação técnica, ❓ decisão do instituto (ver `SDP_DECISOES_PENDENTES.md`).

## 1. Problema — ✅ Confirmado

Institutos e ONGs que oferecem serviços gratuitos (consultas, cursos, atendimento jurídico, entre outros) a pessoas em situação de vulnerabilidade costumam ter recursos limitados frente à demanda. Sem um sistema que organize cadastro, análise de elegibilidade e agendamento, o instituto corre o risco de perder o controle de quem já foi atendido, alocar recursos escassos sem critério auditável, e não conseguir demonstrar de forma transparente como as decisões de atendimento foram tomadas.

## 2. Objetivo — ✅ Confirmado

Construir um sistema de gestão interna para o instituto que centralize cadastro de pessoas atendidas, catálogo de serviços gratuitos, verificação de elegibilidade, agendamento e atendimento — com controle de acesso rigoroso por papel desde o primeiro módulo, e auditoria completa das decisões.

## 3. Público-alvo — ✅ Confirmado

Uso **exclusivamente interno**: funcionários e equipe de gestão do instituto. A pessoa atendida não acessa o sistema diretamente (ver `SDP_DOCUMENTACAO_PROJETO.md`, seção 1.3). O MVP é desenhado para um único instituto — suporte a organizações parceiras é uma decisão em aberto (❓ D02).

## 4. Atores do sistema

| Ator | Descrição | Status |
|---|---|---|
| Administrador | Configuração geral do sistema, gerenciamento de usuários e papéis, cadastro de serviços | 🔧 Recomendação |
| Gestor | Visão gerencial/relatórios; acompanha capacidade, serviços e atendimentos; sem alteração ampla por padrão | 🔧 Recomendação |
| Funcionário | Cadastra pessoas, solicita serviços em nome delas, realiza agendamentos, registra atendimentos | ✅ Confirmado |
| Avaliador de elegibilidade | Analisa critérios e registra decisão de elegibilidade, se existir como função separada | ❓ D05 |
| Auditor | Consulta auditoria e histórico; sem permissão de alteração | 🔧 Recomendação |
| Pessoa atendida | Beneficiária dos serviços; não acessa o sistema diretamente | ✅ Confirmado |
| Organização | O instituto em si e, possivelmente, organizações parceiras | ❓ D02 |

## 5. Requisitos funcionais

**RF01 — Autenticação**
Login, logout real (com revogação de sessão), hash seguro de senha, ativação/desativação de usuários.

**RF02 — Cadastro de pessoas atendidas**
Dados de identificação e contato mínimos necessários — campos exatos ❓ D06. Edição com histórico e auditoria.

**RF03 — Cadastro de funcionários e papéis**
Funcionário vinculado a um usuário do sistema, com um ou mais papéis associados.

**RF04 — Catálogo de serviços**
Serviço genérico e extensível: nome, descrição, organização responsável, capacidade, disponibilidade, se exige avaliação de elegibilidade prévia. Governança de quem cria/edita o catálogo — ❓ D03.

**RF05 — Avaliação de elegibilidade**
Registro de decisão (elegível / não elegível / em avaliação / necessita revisão), responsável, critérios usados, justificativa. Modelo exato (geral vs. por serviço) — ❓ D01.

**RF06 — Agendamento**
Vincula pessoa, serviço, funcionário responsável e data/horário; impede conflito de horário e estouro de capacidade.

**RF07 — Registro de atendimento**
Marca o serviço como realizado. O que exatamente é registrado — ❓ D04.

**RF08 — Auditoria**
Registro de quem fez o quê, quando e sobre qual registro, para toda operação sensível — especialmente decisões de elegibilidade.

**RF09 (condicional) — Organizações parceiras**
Suporte a mais de uma organização oferecendo serviços dentro do mesmo sistema — ❓ D02.

**RF10 (fase futura) — Relatórios gerenciais**
Relatórios de capacidade, atendimentos por serviço, etc.

## 6. Requisitos não funcionais

**RNF01 — Segurança**
As regras de `SEGURANCA.md` (a produzir a partir do checklist de `SDP_DOCUMENTACAO_PROJETO.md`, seção 5) são requisito, não recomendação.

**RNF02 — Privacidade e minimização de dados**
Coletar apenas o que tem finalidade definida. Nada de "pode ser útil no futuro".

**RNF03 — Auditabilidade**
Toda decisão relevante (especialmente elegibilidade) é rastreável: quem, quando, com base em quê.

**RNF04 — Integridade sob concorrência**
Dois agendamentos não podem ocupar a mesma vaga/horário simultaneamente — garantida preferencialmente no próprio banco.

**RNF05 — Usabilidade**
Um funcionário sem treinamento técnico consegue cadastrar uma pessoa e solicitar um serviço após explicação breve.

**RNF06 — Portabilidade**
Ambiente de desenvolvimento reproduzível via Docker/Docker Compose.

**RNF07 — Desempenho**
Meta concreta (ex.: P95 de latência) a definir após uma primeira medição real.

## 7. Fora do escopo do MVP — ✅ Confirmado / 🔧 Recomendação

- Inteligência artificial de qualquer tipo (chatbot, agente autônomo);
- Chat integrado ou qualquer canal de mensagens em tempo real;
- Cobrança, pagamento ou monetização de qualquer serviço;
- Dados clínicos/prontuário completo (a menos que um dos serviços oferecidos seja da área da saúde — ❓ a confirmar);
- Aplicativo mobile nativo;
- Organizações parceiras completas (até D02 ser respondida).

Esses itens ficam registrados como possível roadmap de evolução, não como algo descartado permanentemente.

## 8. Critérios de aceitação do MVP — 🔧 Recomendação (a validar com o instituto)

- Funcionário cadastra uma pessoa e consegue solicitar um serviço para ela.
- Sistema apresenta o resultado da verificação de elegibilidade (mesmo que a decisão final dependa de avaliação humana).
- Funcionário consegue agendar sem conflito de horário/capacidade.
- Atendimento é registrado e aparece no histórico da pessoa.
- Toda decisão de elegibilidade fica auditada com responsável e critério.
- Usuário sem permissão para um recurso recebe erro de autorização, nunca o dado.