import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, afterEach, beforeEach } from "vitest";
import BaseAnalisePage from "./BaseAnalisePage.svelte";
import { _resetFontes } from "@/features/fontes/api/fontesApi.js";

function abrir(query = "") {
  window.history.replaceState({}, "", `/base-analise${query}`);
  return render(BaseAnalisePage);
}

describe("BaseAnalisePage (#439)", () => {
  beforeEach(() => _resetFontes());
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("sem UF: pede a UF e não oferece a base, mas o dicionário sim", async () => {
    abrir();
    expect(await screen.findByTestId("total-recorte")).toHaveTextContent("Escolha a UF");
    expect(screen.queryByTestId("baixar-base")).toBeNull();
    expect(screen.getByTestId("baixar-dicionario").getAttribute("href")).toBe("/api/base-analise/dicionario?");
  });

  it("identificação fixa; blocos marcados mudam a URL e os links", async () => {
    abrir("?uf=ES");
    expect(await screen.findByTestId("total-recorte")).toHaveTextContent("3.010 escolas em funcionamento");
    expect(screen.getByLabelText(/Identificação/)).toBeDisabled();
    expect(screen.getByLabelText(/Identificação/)).toBeChecked();

    await fireEvent.click(screen.getByLabelText(/Infraestrutura/));
    await fireEvent.click(screen.getByLabelText(/IDEB e SAEB por etapa/));
    expect(window.location.search).toBe("?uf=ES&blocos=infraestrutura%2Cdesempenho&ano_ideb=2023");
    expect(screen.getByTestId("baixar-base").getAttribute("href"))
      .toBe("/api/base-analise/csv?uf=ES&blocos=infraestrutura%2Cdesempenho&ano_ideb=2023");
    expect(screen.getByTestId("baixar-dicionario").getAttribute("href"))
      .toBe("/api/base-analise/dicionario?blocos=infraestrutura%2Cdesempenho&ano_ideb=2023");
    expect(screen.getByTestId("versao-dados")).toHaveTextContent("Censo Escolar 2025 · IDEB 2023.");
  });

  it("índices do EduMaps: bloco no link e versão da fórmula na linha da versão (#465)", async () => {
    abrir("?uf=ES");
    await screen.findByTestId("total-recorte");
    expect(screen.getByTestId("versao-dados")).not.toHaveTextContent("índices");
    await fireEvent.click(screen.getByLabelText(/Índices do EduMaps/));
    expect(screen.getByTestId("baixar-base").getAttribute("href")).toBe("/api/base-analise/csv?uf=ES&blocos=indices");
    expect(screen.getByTestId("versao-dados")).toHaveTextContent("Censo Escolar 2025 · índices indices-v2.");
  });

  it("edição do IDEB escolhida vai no link; sem o bloco, o ano some", async () => {
    abrir("?uf=ES&blocos=desempenho&ano_ideb=2021");
    const sel = await screen.findByLabelText("Edição do IDEB");
    expect(sel.value).toBe("2021");
    expect(screen.getByTestId("baixar-base").getAttribute("href")).toContain("ano_ideb=2021");
    await fireEvent.click(screen.getByLabelText(/IDEB e SAEB por etapa/));
    expect(screen.queryByLabelText("Edição do IDEB")).toBeNull();
    expect(screen.getByTestId("baixar-base").getAttribute("href")).toBe("/api/base-analise/csv?uf=ES");
  });

  it("remuneração: ano completo por padrão, no link, na versão e com o aviso de cobertura (#491)", async () => {
    abrir("?uf=ES");
    await screen.findByTestId("total-recorte");
    expect(screen.queryByLabelText("Ano da folha (SIOPE)")).toBeNull();
    await fireEvent.click(screen.getByLabelText(/Remuneração \(SIOPE\)/));
    const sel = screen.getByLabelText("Ano da folha (SIOPE)");
    expect(sel.value).toBe("2025");
    expect(screen.getByTestId("baixar-base").getAttribute("href")).toBe("/api/base-analise/csv?uf=ES&blocos=remuneracao&ano_siope=2025");
    expect(screen.getByTestId("versao-dados")).toHaveTextContent("Censo Escolar 2025 · folha 2025.");
    expect(screen.getByTestId("aviso-siope")).toHaveTextContent("Só a rede municipal");
    await fireEvent.change(sel, { target: { value: "2026" } });
    expect(window.location.search).toContain("ano_siope=2026");
  });

  it("#512: o ano da folha segue a UF, com a cobertura e o aviso de recorte vazio", async () => {
    abrir("?uf=SP");
    await screen.findByTestId("total-recorte");
    await fireEvent.click(screen.getByLabelText(/Remuneração \(SIOPE\)/));
    const sel = screen.getByLabelText("Ano da folha (SIOPE)");
    expect(sel.value).toBe("2026");
    expect(screen.getByTestId("cobertura-siope")).toHaveTextContent("Ubatuba (2026: 8 meses (julho incompleto), 48 escolas; carga não registrada)");
    expect(screen.getByTestId("cobertura-siope")).toHaveTextContent("Taubaté (2026: só o total da Secretaria; carga não registrada)");
    expect(screen.getByTestId("folha-recorte")).toHaveTextContent("48 escolas deste recorte têm folha em 2026");
    // #554: de onde vem o total declarado, por município
    expect(screen.getByTestId("fechamento-folha")).toHaveTextContent("Ubatuba: R$ 67,7 mi declarados em 2026");
    expect(screen.getByTestId("fechamento-folha")).toHaveTextContent("35659605, JOSE LIBORIO - SEU FRANCA EM");
    expect(screen.getByTestId("fechamento-folha")).toHaveTextContent("Taubaté: R$ 163,3 mi declarados em 2026. Da Secretaria");
    // #571: o salário do magistério da rede inteira, com a Secretaria
    expect(screen.getByTestId("salario-rede-base")).toHaveTextContent("Taubaté: salário total R$ 6.975 e base R$ 2.669");
    // #575: o piso na rede inteira (Ubatuba), com a Secretaria
    expect(screen.getByTestId("piso-rede-base")).toHaveTextContent("6 profissionais do magistério, 3 deles só no total da Secretaria");
    expect(screen.getByTestId("salario-rede-base")).toHaveTextContent("carga mais comum: 31. Abaixo do piso");
    expect(screen.getByTestId("baixar-base").getAttribute("href")).toContain("ano_siope=2026");

    // escolher outro ano: vale a escolha, com o aviso de que sai vazio
    await fireEvent.change(sel, { target: { value: "2025" } });
    expect(screen.getByTestId("aviso-folha-vazia")).toHaveTextContent("Nenhuma escola deste recorte tem folha em 2025");
    expect(screen.getByTestId("aviso-folha-vazia")).toHaveTextContent("Anos com folha em SP: 2026");
  });

  it("#554: com o município no recorte, só a conta dele", async () => {
    abrir("?uf=SP&codigo_ibge=3555406&blocos=remuneracao");
    const f = await screen.findByTestId("fechamento-folha");
    expect(f).toHaveTextContent("Ubatuba: R$ 67,7 mi declarados em 2026");
    expect(f).not.toHaveTextContent("Taubaté");
  });

  it("#512: UF sem folha diz que o bloco sai vazio e fica no padrão do Brasil", async () => {
    abrir("?uf=ES&blocos=remuneracao");
    expect(await screen.findByTestId("cobertura-siope")).toHaveTextContent("Nenhum município de ES");
    expect(screen.getByLabelText("Ano da folha (SIOPE)").value).toBe("2025");
  });

  it("rede filtra a contagem e entra no link", async () => {
    abrir("?uf=ES");
    await screen.findByText(/3\.010/);
    await fireEvent.change(screen.getByLabelText("Rede"), { target: { value: "municipal" } });
    expect(await screen.findByText(/1\.200/)).toBeInTheDocument();
    expect(screen.getByTestId("baixar-base").getAttribute("href")).toBe("/api/base-analise/csv?uf=ES&rede=municipal");
    expect(window.location.search).toBe("?uf=ES&rede=municipal");
  });

  it("IDEB e Censo de anos diferentes: avisa o cruzamento, inclusive na edição mais recente (#444, #514)", async () => {
    abrir("?uf=ES&blocos=desempenho");
    await screen.findByLabelText("Edição do IDEB");
    // edição mais recente (2023) contra o Censo 2025: também avisa (#514)
    const recente = await screen.findByTestId("aviso-anos");
    expect(recente).toHaveTextContent("são do Censo 2025; o IDEB é de 2023 (dois anos antes)");
    expect(recente).toHaveTextContent("Escolas fechadas depois de 2023 não entram");
    expect(recente).toHaveTextContent("medido depois do IDEB");
    expect(screen.getByTestId("aviso-anos-baixar")).toBeInTheDocument();

    await fireEvent.change(screen.getByLabelText("Edição do IDEB"), { target: { value: "2021" } });
    const aviso = await screen.findByTestId("aviso-anos");
    expect(aviso).toHaveTextContent("são do Censo 2025; o IDEB é de 2021 (quatro anos antes)");
    expect(aviso).toHaveTextContent("Escolas fechadas depois de 2021 não entram");

    await fireEvent.click(screen.getByLabelText(/IDEB e SAEB por etapa/));
    expect(screen.queryByTestId("aviso-anos")).toBeNull();
    expect(screen.queryByTestId("aviso-anos-baixar")).toBeNull();
  });

  it("com o INSE marcado, o aviso diz a edição do SAEB (#514)", async () => {
    abrir("?uf=ES&blocos=desempenho,inse");
    expect(await screen.findByTestId("aviso-anos")).toHaveTextContent("O INSE é da edição 2023 do SAEB, a mesma do IDEB");
    await fireEvent.change(screen.getByLabelText("Edição do IDEB"), { target: { value: "2021" } });
    expect(await screen.findByTestId("aviso-anos")).toHaveTextContent("diferente da do IDEB (2021)");
  });

  it("diz que o link traz a carga mais recente e que o arquivo é o que se cita (#444)", async () => {
    abrir("?uf=ES");
    expect(await screen.findByTestId("aviso-link")).toHaveTextContent("traz sempre a carga mais recente");
  });

  it("parâmetros inválidos na URL são ignorados", async () => {
    abrir("?uf=ES&blocos=salarios,inse&rede=comunitaria&ano_ideb=1990");
    await screen.findByText(/3\.010/);
    expect(screen.getByLabelText(/Nível socioeconômico/)).toBeChecked();
    expect(screen.getByLabelText("Rede").value).toBe("");
    const href = screen.getByTestId("baixar-base").getAttribute("href");
    expect(href).toBe("/api/base-analise/csv?uf=ES&blocos=inse");
  });

  it("IDEB sem as etapas: dica e botão que marca as etapas (#461)", async () => {
    abrir("?uf=ES&blocos=desempenho");
    expect(await screen.findByTestId("dica-etapas")).toHaveTextContent("mistura \"não oferece a etapa\" e \"não teve nota\"");
    await fireEvent.click(screen.getByRole("button", { name: "Marcar também as etapas oferecidas" }));
    expect(screen.queryByTestId("dica-etapas")).toBeNull();
    expect(screen.getByLabelText(/Etapas oferecidas/)).toBeChecked();
    expect(window.location.search).toContain("blocos=desempenho%2Cetapas");
  });

  it("sem o IDEB, sem a dica", async () => {
    abrir("?uf=ES&blocos=infraestrutura");
    await screen.findByText(/3\.010/);
    expect(screen.queryByTestId("dica-etapas")).toBeNull();
  });
});
