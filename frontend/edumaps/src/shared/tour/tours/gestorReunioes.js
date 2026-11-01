// src/shared/tour/tours/gestorReunioes.js
//
// Tour de reuniões e atas (/gestor/reunioes). Exige login.
// Textos conferidos com docs/funcionalidades/gestor/reunioes-atas.md e o
// código (o botão “Agenda” do cabeçalho leva aos CONTATOS, não a um
// calendário; convite por WhatsApp/e-mail fica no ConviteBox do assistente).

export default {
  id: "gestor-reunioes",
  versao: 1,
  titulo: "Reuniões e atas",
  rotaInicial: "/gestor/reunioes",
  automatico: true,
  prontoQuando: "reunioes-lista",
  passos: [
    {
      alvo: "reunioes-filtros",
      titulo: "Encontrar uma reunião",
      texto:
        "Busque pelo título e filtre por status (agendadas, realizadas, canceladas) e por período. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "reunioes-lista",
      titulo: "Suas reuniões",
      texto:
        "Cada reunião mostra o status, se a ata já foi salva, a forma de aviso, a data, a duração e os participantes. " +
        "Uma agendada pode ser marcada como realizada, cancelada ou editada; “Abrir” leva à ata e aos anexos.",
      lado: "top",
    },
    {
      alvo: "reunioes-nova",
      titulo: "Nova reunião",
      texto:
        "Defina data, duração, local ou link e a forma de aviso, escolha os participantes por contato ou por grupo " +
        "e copie o convite pronto para mandar por WhatsApp ou e-mail.",
      lado: "bottom",
      alinhamento: "end",
    },
    {
      alvo: "reunioes-agenda",
      titulo: "Agenda de contatos",
      texto:
        "“Agenda” abre os seus contatos e grupos, de onde saem os participantes. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
