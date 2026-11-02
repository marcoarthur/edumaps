---
titulo: "Montar o inventário da escola"
publico: [gestor]
modulo: gestor
nivel: basico
status: ativo
relacionadas: [documentos-e-planos, painel-da-escola]
funcionalidade: ../../funcionalidades/gestor/inventario.md
ultima_revisao: 2026-11-02
---

# Montar o inventário da escola

> **Para quem:** gestor que quer registrar os bens, as contas e os contratos da escola.
> **Tempo de leitura:** ~4 min

## Em 30 segundos

O inventário começa pelo que o Censo Escolar registra sobre a sua escola. Você
importa esse retrato com um clique e depois acrescenta o que o Censo não
captura: bens com estado e valor, contas e contratos com periodicidade,
fornecedores, fotos e notas fiscais. A importação não altera os dados do Censo.

## Passo a passo

1. **Onde ir:** menu **Gestor** → **Ir para o painel** → **Inventário**. Se a
   sessão tiver expirado, a página pede que você entre de novo.
2. **O que ver:** quatro abas.
   - **Do Censo**: o que o Censo Escolar registra (dispositivos, equipamentos,
     materiais pedagógicos, espaços e salas, infraestrutura e serviços
     básicos, conectividade), só para leitura.
   - **Recursos**: os bens da escola.
   - **Serviços**: contas e contratos (água, luz, internet, manutenção…).
   - **Fornecedores**: fornecedores e prestadores.
3. **Começar pelo Censo:** na aba **Do Censo**, clique em **Importar para o
   inventário**. Os itens vão para **Recursos** e **Serviços**, já com
   categorias (Computadores, Espaços e salas, Conectividade…) e a marca “censo”.
4. **Criar uma categoria própria:** em **Recursos** ou **Serviços**, use
   **+ Categoria**, dê o nome (ex.: “Material de limpeza”) e clique em
   **Criar**. A categoria vale para a aba em que foi criada.
5. **Cadastrar um item:** **+ Novo recurso** ou **+ Novo serviço**. Só
   **Nome** e **Categoria** são obrigatórios. Os demais campos: **Fornecedor**,
   **Quantidade**, **Unidade**, **Estado**, **Valor (R$)**, **Identificador**
   (nº de série, da conta ou do contrato), **Periodicidade**, **Data de
   aquisição** e **Descrição**. Unidade, estado e periodicidade sugerem
   opções, mas aceitam texto livre. Clique em **Salvar**.
6. **Campos próprios:** no mesmo formulário, **+ atributo** acrescenta pares
   “chave / valor” (ex.: “sala / 12”, “patrimônio / 004512”).
7. **Anexar fotos e notas fiscais:** salve o item primeiro; depois clique em
   **Editar** e, em **Anexos (fotos, notas fiscais)**, use **+ enviar**. Clique
   no nome do anexo para baixá-lo.
8. **Cadastrar fornecedores:** aba **Fornecedores** → **+ Novo fornecedor**
   (**Nome**, **Tipo de serviço**, **Documento**, **E-mail**, **Telefone**,
   **Site**, **Observações**) → **Salvar**. Depois, escolha o fornecedor no
   campo **Fornecedor** de cada item.
9. **Como saber que deu certo:** o item aparece na lista da aba com categoria,
   quantidade, valor, estado, fornecedor e número de anexos, e o contador
   “N item(ns)” aumenta.

## Entendendo os números

- A aba **Do Censo** mostra o ano usado (“Dados do Censo Escolar 2025”). Cada
  item traz a quantidade (“3 un”) quando o Censo a informa, ou “presente”
  quando o Censo só diz que existe.
- **A aba Do Censo só lista o que o Censo registrou como existente.** Um item
  que não aparece não quer dizer que a escola não o tenha: pode não ter sido
  declarado. Ausência no Censo nunca é zero; cadastre o que você sabe que existe.
- Itens importados que o Censo só marca como “presente” entram com
  quantidade **1**: isso indica que existe, não que foi contado. Ajuste a
  quantidade real em **Editar**.
- Campo vazio não vira zero: um item sem valor simplesmente não mostra valor.
  A exceção é a **Quantidade**: deixada em branco, é salva como 1.
- “Sem dados de Censo para esta escola.” significa que não há registro do
  Censo daquele ano para a escola; o inventário manual funciona normalmente.

## Limitações conhecidas

- O retrato do Censo é de um ano fixo (2025); ainda não é possível escolher
  outro ano.
- **Importar de novo** só traz o que ainda não está no inventário. Se você
  excluiu um item importado, ele volta numa nova importação.
- Não há campo de **vencimento** ou **fim de contrato**: use
  **Periodicidade**, **Data de aquisição**, um atributo livre (ex.: “vence em /
  31/12/2026”) ou anexe o contrato.
- Anexos só podem ser enviados depois de o item ser salvo. Aceitam PDF, DOCX,
  XLSX, PNG, JPG e TXT, até 10 MB. O ✕ remove o anexo na hora, sem pedir
  confirmação.
- Categorias criadas pela importação do Censo não podem ser excluídas; as suas
  podem (o ✕ ao lado do nome), mas só se não tiverem itens.
- Não pode haver duas categorias com o mesmo nome na mesma aba, nem dois
  fornecedores com o mesmo nome.
- O valor aparece na lista como foi gravado, sem separador de milhar
  (ex.: “R$ 1500.5”).
- Não há busca, filtro nem exportação do inventário, e as alterações nos itens
  não ficam num histórico.

## Privacidade

Fornecedores podem ser pessoas físicas: **Documento** (CPF), **E-mail** e
**Telefone** são dados pessoais. Eles ficam visíveis apenas para quem entra
como gestor desta escola. Cadastre só o necessário para a relação com o
fornecedor e mantenha os dados atualizados. Ao excluir um fornecedor, os itens
ligados a ele continuam no inventário, apenas sem fornecedor.

## Perguntas frequentes

- **Importei e apareceu “Nada novo para importar do Censo.”?** Tudo o que o
  Censo registra já está no seu inventário.
- **Não consigo criar um item: pede para selecionar uma categoria.** A aba
  ainda não tem categorias. Crie uma em **+ Categoria** ou importe do Censo.
- **Mudar o item no inventário altera o Censo?** Não. O inventário é uma
  cópia sua; a aba **Do Censo** continua mostrando o dado oficial.

## Veja também

- [Guardar documentos e planos da escola](documentos-e-planos.md)
- [Painel da escola](painel-da-escola.md)
- Ficha da funcionalidade: [Inventário escolar](../../funcionalidades/gestor/inventario.md)
