# Regras de Negócio — Sentindo a Dor do Próximo

> Este documento é normativo. Toda Pull Request que violar uma regra aqui descrita deve ser rejeitada na revisão de código, independentemente de quem escreveu. Para as regras de segurança transversais, ver `SDP_DOCUMENTACAO_PROJETO.md`, seção 5.
>
> ✅ **Todas as 9 decisões de negócio (D01–D09) estão fechadas** — ver `SDP_DECISOES_PENDENTES.md`. O schema definitivo correspondente está em `BANCO_DADOS.md`.

## 1. Princípios fundamentais

### 1.1 Princípio do menor privilégio

Todo usuário, serviço e integração recebe **apenas** o acesso mínimo necessário para exercer sua função:

- **Acesso técnico de infraestrutura** (banco de dados, deploy, variáveis de ambiente/secrets) **não é um papel de negócio da aplicação** — não deve existir como valor de `papeis.nome`, nem ser usado para autenticação de usuário final em produção. É controlado separadamente, fora do sistema, com contas de infraestrutura próprias (`db_owner`/`app_runtime`, T04).
- **Administrador**: acesso amplo (usuários, papéis, catálogo de serviços, configuração), mas não irrestrito — não altera dados protegidos por regra de imutabilidade (seção 1.2) nem contorna auditoria.
- **Recepcionista**: acesso operacional — cadastro de pessoas, elegibilidade, solicitação de serviço, agendamento e atendimento (detalhado na seção 4).

> ⚠️ **RBAC reduzido a 2 papéis de negócio** — decisão do responsável técnico do projeto, não uma resposta do instituto a uma pergunta D01–D09 como as demais desta lista. Os papéis "Gestor" e "Auditor", que existiam como recomendação preliminar, saíram do MVP. Isso é razoável tecnicamente, mas remover um papel de auditoria/leitura separado da operação é uma decisão com implicação de segregação de função — vale confirmação explícita de quem responde pelo instituto antes de produção.

### 1.2 Dados de identificação — imutabilidade (✅ D06 fechada)

`nome`, `rg`, `cpf` e `data_nascimento` da pessoa atendida são **campos protegidos**: imutáveis por `UPDATE` direto, garantido por trigger no banco (não apenas na aplicação). Correção de erro real de cadastro passa pela tabela `correcoes_cadastrais` — justificativa, aprovador, vínculo ao registro original, nunca `UPDATE` silencioso.

> 🔎 **Registrado para o futuro, não uma pendência:** RG e CPF são sempre obrigatórios no cadastro — confirmado explicitamente pelo instituto, mesmo sabendo que isso impede o cadastro de pessoas sem documento (situação real em população em vulnerabilidade — morador de rua, migrante em situação irregular, etc.). Se essa política mudar um dia, é um ajuste de `NOT NULL`, não uma reestruturação — mas a consequência de quem fica de fora do sistema hoje deve continuar visível, não escondida atrás de "decisão já fechada".

### 1.3 Sobre dados financeiros

Este projeto **não envolve cobrança, pagamento ou monetização de serviço** (ver `REQUISITOS.md`, seção 7) — os serviços do instituto são gratuitos. Não existe, portanto, uma regra de "pagamentos append-only" nesta versão. Caso o instituto venha a registrar doações ou outro fluxo financeiro no futuro, recomenda-se aplicar o mesmo princípio de registro somente-inserção já usado em auditoria e elegibilidade (seção 2) — mas isso é uma extensão futura, não parte do escopo atual.

## 2. Elegibilidade (✅ D01 fechada)

Elegibilidade é **geral por pessoa**, decidida pela Recepcionista no momento do cadastro/primeiro atendimento, com base em: recebimento de benefício do governo, participação em projeto social, renda familiar. Uma vez elegível, a pessoa pode utilizar qualquer serviço disponível, sem limite de uso — sujeito apenas ao pré-requisito objetivo do serviço específico (seção 3) e à disponibilidade de agenda (seção 5).

Estados conceituais:

```text
PENDENTE → EM_AVALIACAO → { ELEGIVEL | NAO_ELEGIVEL | NECESSITA_REVISAO }
```

Toda decisão registra: responsável, data, critérios usados e justificativa quando aplicável. **Reavaliação é possível** — gera um novo registro histórico, nunca sobrescreve o anterior; a decisão vigente é sempre a mais recente.

**Regra explícita:** o sistema organiza dados, verifica critérios objetivos e sinaliza inconsistências — mas **não inventa critério de elegibilidade**; os critérios acima são os que o instituto confirmou.

## 3. Pré-requisito objetivo por serviço (✅ D07 fechada)

Diferente da elegibilidade (seção 2, decisão humana única por pessoa), o pré-requisito de serviço é uma **checagem automática de dado cadastral**, específica de cada serviço. Só três tipos existem, confirmado como lista fechada:

- Idade mínima
- Escolaridade mínima (comparável por nível — `Fundamental incompleto` < `Fundamental completo` < ... < `Superior completo` — nunca comparação de texto livre)
- Exigência de CNH

A checagem acontece automaticamente no momento da solicitação, e o resultado (**atendido ou não**) fica gravado como snapshot na própria solicitação — não é recalculado depois, mesmo que o serviço mude seus requisitos ou a pessoa complete escolaridade posteriormente. Isso preserva RNF03 (auditabilidade): uma solicitação antiga sempre mostra o critério que foi realmente usado para aprovar/recusar naquele momento.

## 4. Controle de acesso (RBAC) (✅ fechado)

| Recurso | Administrador | Recepcionista |
|---|---|---|
| Cadastro de pessoas | Leitura | Leitura/Escrita |
| Cadastro de usuários/papéis | Leitura/Escrita | — |
| Catálogo de serviços | Leitura/Escrita | Leitura |
| Organizações parceiras (cadastro) | Leitura/Escrita | Leitura |
| Solicitação de serviço | Leitura | Leitura/Escrita |
| Avaliação de elegibilidade | Leitura | Leitura/Escrita |
| Agenda (datas/capacidade) | Leitura | Leitura/Escrita — sempre em nome do profissional (D09) |
| Agendamento e fila de espera | Leitura | Leitura/Escrita |
| Atendimento (registro) | Leitura | Leitura/Escrita |
| Exportação de PDF de encaminhamento | Leitura/Escrita | Leitura/Escrita |
| Auditoria/Logs | Leitura | — |
| Configuração do sistema | Leitura/Escrita | — |

Célula em branco significa **sem acesso**, não acesso implícito. Esta tabela é a fonte única de verdade de autorização — qualquer exceção precisa ser adicionada explicitamente aqui antes de virar código.

D05 (✅ fechada) confirmou que a mesma pessoa cadastra e decide elegibilidade — não existe papel "Avaliador" separado, por isso ele nunca aparece nesta tabela.

## 5. Agenda, agendamento e fila de espera (✅ D08, D09 fechadas)

O profissional (médico, professor etc.) que executa um serviço **nunca loga no sistema** (D09) — a Recepcionista cadastra as datas e a capacidade disponíveis sempre em nome dele. Não existe papel "Profissional" no RBAC.

Ao solicitar um serviço, o sistema decide, numa única transação que trava a linha da data, se aloca vaga ou envia para fila de espera (D08) — essa decisão acontece **antes** de qualquer tentativa de inserir o agendamento, não como reação a um erro de capacidade excedida. Fila de espera é o caso comum de um serviço popular, não uma exceção.

## 6. Atendimento (✅ D04 fechada): só compareceu/não compareceu

Registrar o atendimento marca `compareceu = true/false` e atualiza automaticamente o status do agendamento correspondente (`concluido`/`nao_compareceu`). **Nenhum campo de observação livre** — decisão explícita do instituto, não omissão de modelagem.

Este sistema **não registra dado clínico/prontuário** — nenhum serviço confirmado até agora é da área da saúde (ver `SDP_DOCUMENTACAO_PROJETO.md`, seção 1.4). Se isso mudar no futuro, é uma decisão nova, com seu próprio processo de definição — não uma extensão silenciosa do campo `compareceu`.

## 7. Organizações parceiras (✅ D02 fechada)

Parceiros externos (ex.: advogado) existem hoje e podem existir mais no futuro, mas **nunca têm acesso ao sistema** — nem login, nem visualização direta de dados de pessoas atendidas. O vínculo entre um serviço e uma organização parceira é só metadado de referência (`servicos.organizacao_id`). Quando é necessário passar informação a um parceiro, isso acontece por **exportação pontual de PDF de encaminhamento** (nome, endereço, dados acadêmicos conforme o tipo de encaminhamento) — nunca por acesso direto ao sistema.

## 8. Confirmação e cancelamento de agendamento

A pessoa atendida não acessa o sistema — confirmação, cancelamento e reagendamento são sempre registrados pela Recepcionista em nome da pessoa. Isso faz parte do fluxo de agendamento desde a primeira sprint em que ele é construído, não é funcionalidade de fase futura.

## 9. Como este documento deve ser usado

- Toda nova funcionalidade entra no backlog já referenciando qual regra desta lista ela precisa respeitar.
- Toda revisão de código (Pull Request) verifica: a regra foi seguida? Se não, o PR não é aprovado — mesmo que o código "funcione".
- Alterações neste documento exigem discussão em equipe e registro do motivo.
- As decisões técnicas pendentes (T03–T09, ver `SDP_DECISOES_PENDENTES.md`) não bloqueiam este documento — são operacionais (hospedagem, criptografia, backup, ambientes), não regra de negócio.
- A seção 9 (Central de Atendimento) é a única deste documento sem decisão D0x rastreável — trate com mais cautela que as demais até isso ser esclarecido.
