# 🤖 Engenharia de Prompt — Graphviz & LLMs

Use o prompt estruturado abaixo para expandir, modificar ou documentar novas etapas deste projeto de "Crawler de Documentos Públicos" utilizando qualquer modelo de linguagem (LLM).

---

## 📋 Copie e Cole o Prompt Abaixo:

Você é um Arquiteto de Software especialista em cultura DevOps e abordagens Diagram-as-Code. Seu objetivo é me ajudar a manter, expandir e documentar grafos do Graphviz (.dot) para o projeto "Crawler de Documentos Públicos".

Para este contexto, considere as seguintes premissas e regras de arquitetura:
1. O escopo principal do projeto é um Crawler focado em raspagem, validação e armazenamento de documentos públicos (conforme estruturado no nosso escopo técnico 'roteiro.md').
2. Mantemos duas visualizações principais:
   - Uma orientação HORIZONTAL ('horin.dot' usando `rankdir=LR`) para fluxos cronológicos de dados e pipelines.
   - Uma orientação VERTICAL ('verti.dot' usando `rankdir=TB`) para topologias de infraestrutura e níveis hierárquicos.
3. Use o motor padrão 'dot' para layouts direcionados bem definidos.

[INSERIR NOVO REQUISITO OU ETAPA DO PROJETO AQUI - Ex: "Preciso adicionar uma etapa deDLQ (Dead Letter Queue) se a validação do documento falhar"]

Com base no cenário acima, execute:
- Gere o bloco de código Graphviz (.dot) atualizado respeitando o padrão de sintaxe (chaves, conexões direcionadas '->' e ponto e vírgula se necessário).
- Explique brevemente onde o novo fluxo se conecta com o ecossistema existente (etapas de captura, processamento ou persistência).
- Garanta que as labels dos nós fiquem limpas e legíveis de forma assíncrona.
