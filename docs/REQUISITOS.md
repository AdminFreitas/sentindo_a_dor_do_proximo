# Requisitos do Projeto — Sentindo a Dor do Próximo

> Este documento detalha os requisitos apresentados em `SDP_DOCUMENTACAO_PROJETO.md`. Os selos ✅/🔧/❓ seguem a convenção: ✅ confirmado, 🔧 recomendação técnica, ❓ decisão do instituto (ver `SDP_DECISOES_PENDENTES.md`).
>
> ✅ **D01–D09 fechadas.** Todas as decisões de negócio que bloqueavam requisitos estão resolvidas. Este documento também incorpora a Central de Atendimento omnichannel (Fase 1) — ver ressalva na seção 9 sobre a origem dessa confirmação.

## 1. Problema — ✅ Confirmado

Institutos e ONGs que oferecem serviços gratuitos (consultas, cursos, atendimento jurídico, entre outros) a pessoas em situação de vulnerabilidade costumam ter recursos limitados frente à demanda. Sem um sistema que organize cadastro, análise de elegibilidade e agendamento, o instituto corre o risco de perder o controle de quem já foi atendido, alocar recursos escassos sem critério auditável, e não conseguir demonstrar de forma transparente como as decisões de atendimento foram tomadas.

## 2. Objetivo — ✅ Confirmado

Construir um sistema de gestão interna para o instituto que centralize cadastro de pessoas atendidas, catálogo de serviços gratuitos, verificação de elegibilidade, agendamento e atendimento — com controle de acesso rigoroso por papel desde o primeiro módulo, auditoria completa das decisões, e organização de contato multicanal (Central de Atendimento).

## 3. Público-alvo — ✅ Confirmado

Uso **exclusivamente interno**: administrador e recepcionista do instituto. A pessoa atendida não acessa o sistema diretamente. O MVP é para um único instituto — organizações parceiras existem (D02), mas nunca têm acesso ao sistema.

## 4. Atores do sistema

| Ator | Descrição | Status |
|---|---|---|
| Administrador | Configuração do sistema, usuários e papéis, catálogo de serviços (D03) | ✅ Confirmado |
| Recepcionista | Cadastra pessoas, decide elegibilidade, solicita serviços, agenda, registra atendimento, opera a Central de Atendimento | ✅ Confirmado — inclui as permissões que antes seriam de "Avaliador" (D05: mesma pessoa) |
| Pessoa atendida | Beneficiária dos serviços; não acessa o sistema diretamente | ✅ Confirmado |
| Organização parceira | Executa serviço (ex.: advogado); **nunca tem acesso ao sistema** | ✅ Confirmado — D02 |
| Profissional (médico, professor etc.) | Executa o serviço; **nunca loga no sistema** — agenda cadastrada pela Recepcionista em nome dele | ✅ Confirmado — D09 |

Os papéis "Gestor" e "Auditor", cogitados em versão anterior deste documento, **não existem** no MVP — ver `REGRAS_NEGOCIO.md`, seção 4, para a ressalva de que essa simplificação foi decisão técnica, não resposta do instituto a um D0x.

## 5. Requisitos funcionais

**RF01 — Autenticação**
Login, logout real (com revogação de sessão), hash seguro de senha, ativação/desativação de usuários.

**RF02 — Cadastro de pessoas atendidas** ✅ D06 fechada
Nome, RG, CPF (sempre obrigatórios), data de nascimento (campos protegidos, imutáveis); telefone, e-mail, endereço estruturado (CEP/logradouro/número/bairro/cidade/UF), título de eleitor (opcional); escolaridade e CNH (opcionais, por demanda de pré-requisito de serviço).

**RF03 — Cadastro de usuários e papéis**
Usuário do sistema com um ou mais papéis associados (administrador, recepcionista).

**RF04 — Catálogo de serviços** ✅ D02, D03, D07 fechadas
Serviço genérico: nome, descrição, organização responsável (opcional), pré-requisito objetivo opcional (idade mínima, escolaridade mínima, CNH — lista fechada, nenhum outro tipo). Escrita restrita a Administrador.

**RF05 — Avaliação de elegibilidade** ✅ D01 fechada
Elegibilidade **geral por pessoa**, decidida pela Recepcionista, com base em benefício do governo, projeto social, renda familiar. Reavaliável a qualquer momento; decisão vigente é sempre a mais recente.

**RF06 — Agendamento e fila de espera** ✅ D08 fechada
Vincula pessoa (via solicitação de serviço) a uma data de agenda; capacidade decidida em transação; excedente vai para fila de espera automaticamente, sem erro.

**RF07 — Registro de atendimento** ✅ D04 fechada
Só `compareceu`/`não compareceu`. Sem campo de observação livre — decisão explícita, não omissão.

**RF08 — Auditoria**
Registro de quem fez o quê, quando e sobre qual registro, para toda operação sensível — especialmente decisões de elegibilidade.

**RF09 — Organizações parceiras** ✅ D02 fechada
Cadastro simples de organização, vinculável a serviço; parceiro nunca loga no sistema.

**RF10 (fase futura) — Relatórios gerenciais**
Relatórios de capacidade, atendimentos por serviço, etc.

**RF11 — Exportação de PDF de encaminhamento** ✅ D02 fechada
Gera PDF com dados pertinentes da pessoa (nome, endereço, dados acadêmicos) para entregar a uma organização parceira, sem dar acesso ao sistema.

**RF12 — Central de Atendimento omnichannel, Fase 1** (ver seção 9)
Registro organizado de contato vindo de site, WhatsApp, Instagram, Facebook, TikTok, e-mail, telefone ou presencial — Fase 1: registro manual do canal pela Recepcionista, sem integração de API ainda.

## 6. Requisitos não funcionais

**RNF01 — Segurança**
As regras de `SEGURANCA.md` são requisito, não recomendação.

**RNF02 — Privacidade e minimização de dados**
Coletar apenas o que tem finalidade definida.

**RNF03 — Auditabilidade**
Toda decisão relevante é rastreável: quem, quando, com base em quê.

**RNF04 — Integridade sob concorrência**
Duas solicitações não podem ocupar a mesma vaga de capacidade — garantido no banco via transação (`FOR UPDATE`), não só na aplicação.

**RNF05 — Usabilidade**
Uma recepcionista sem treinamento técnico consegue cadastrar uma pessoa e solicitar um serviço após explicação breve.

**RNF06 — Portabilidade**
Ambiente de desenvolvimento reproduzível via Docker/Docker Compose.

**RNF07 — Desempenho**
Meta concreta (ex.: P95 de latência) a definir após uma primeira medição real.

## 7. Fora do escopo — ✅ Confirmado

- Inteligência artificial de qualquer tipo (chatbot, agente autônomo, triagem automática);
- Cobrança, pagamento ou monetização de qualquer serviço;
- Dados clínicos/prontuário completo (nenhum serviço confirmado até agora é da área da saúde);
- Aplicativo mobile nativo.

> ⚠️ **Correção em relação à versão anterior:** este documento antes listava "chat integrado ou qualquer canal de mensagens em tempo real" como fora do escopo. Isso deixou de ser verdade com a Central de Atendimento (RF12, seção 9) — o item foi removido daqui. A exclusão de **IA/chatbot automatizado** continua valendo integralmente; o que mudou é que o sistema agora organiza canais de mensagem operados por humano.

## 8. Critérios de aceitação do MVP

- Recepcionista cadastra uma pessoa (RG/CPF obrigatórios) e consegue solicitar um serviço para ela.
- Sistema aplica o pré-requisito objetivo do serviço (se houver) e mostra o resultado.
- Sistema apresenta o resultado da elegibilidade geral da pessoa.
- Recepcionista consegue agendar; se a data estiver lotada, a solicitação vai para fila de espera automaticamente, sem erro visível ao usuário.
- Atendimento é registrado (compareceu/não compareceu) e atualiza o status do agendamento automaticamente.
- Toda decisão de elegibilidade fica auditada com responsável e critério.
- Usuário sem permissão para um recurso recebe erro de autorização, nunca o dado (teste IDOR).
- Uma conversa pode ser registrada com canal de origem e pessoa ainda não identificada, e depois vinculada a uma pessoa cadastrada.

## 9. Central de Atendimento omnichannel — ressalva de proveniência

> ⚠️ Diferente de RF01–RF11, o RF12 (Central de Atendimento) não tem uma decisão D0x rastreável em `SDP_DECISOES_PENDENTES.md` — não há registro de quem no instituto confirmou este requisito, nem quando. Já existe arquitetura e schema desenhados em cima dele (`ARQUITETURA.md`, `BANCO_DADOS.md`), mas isso não substitui o registro formal da decisão. Recomenda-se formalizar como D10 antes de considerar este requisito no mesmo nível de confiança dos demais.
