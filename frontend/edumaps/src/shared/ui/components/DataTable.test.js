import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import { createRawSnippet } from "svelte";
import DataTable from "./DataTable.svelte";

describe("DataTable", () => {
  const columns = [
    { key: "name", label: "Name" },
    { key: "age", label: "Age", sortable: true },
  ];
  const data = [
    { id: 1, name: "Alice", age: 30 },
    { id: 2, name: "Bob", age: 25 },
    { id: 3, name: "Charlie", age: 35 },
  ];

  it("renders table with caption and footer", () => {
    render(DataTable, {
      columns,
      data,
      caption: "Test Caption",
      footer: "Total: 3 rows",
    });

    expect(screen.getByText("Test Caption")).toBeInTheDocument();
    expect(screen.getByText("Total: 3 rows")).toBeInTheDocument();
    expect(screen.getByText("Alice")).toBeInTheDocument();
  });

  it("sorts data when clicking a sortable column header", async () => {
    render(DataTable, { columns, data });

    const ageHeader = screen.getByText("Age");
    // Initial order: Alice (30), Bob (25), Charlie (35) -> unsorted (original)
    const cells = screen.getAllByText(/Alice|Bob|Charlie/);
    expect(cells[0].textContent).toBe("Alice");

    // First click => ascending (Bob 25, Alice 30, Charlie 35)
    await fireEvent.click(ageHeader);
    const cellsAsc = screen.getAllByText(/Alice|Bob|Charlie/);
    expect(cellsAsc[0].textContent).toBe("Bob");
    expect(cellsAsc[1].textContent).toBe("Alice");
    expect(cellsAsc[2].textContent).toBe("Charlie");

    // Second click => descending
    await fireEvent.click(ageHeader);
    const cellsDesc = screen.getAllByText(/Alice|Bob|Charlie/);
    expect(cellsDesc[0].textContent).toBe("Charlie");
    expect(cellsDesc[1].textContent).toBe("Alice");
    expect(cellsDesc[2].textContent).toBe("Bob");

    // Third click => unsorted (back to original)
    await fireEvent.click(ageHeader);
    const cellsUnsorted = screen.getAllByText(/Alice|Bob|Charlie/);
    expect(cellsUnsorted[0].textContent).toBe("Alice");
  });

  it("does not sort when column is not sortable", async () => {
    const columnsNonSortable = [
      { key: "name", label: "Name", sortable: false },
      { key: "age", label: "Age" },
    ];
    render(DataTable, { columns: columnsNonSortable, data });

    const nameHeader = screen.getByText("Name");
    await fireEvent.click(nameHeader);
    const cells = screen.getAllByText(/Alice|Bob|Charlie/);
    expect(cells[0].textContent).toBe("Alice");
  });

  it("renders custom cell content via render prop", () => {
    const columnsWithRender = [
      { key: "name", label: "Name" },
      {
        key: "age",
        label: "Age",
        render: (row) => `${row.age} years`,
      },
    ];
    render(DataTable, { columns: columnsWithRender, data });
    expect(screen.getByText("30 years")).toBeInTheDocument();
  });

  it("renders a snippet passed via cell", () => {
    const badge = createRawSnippet((row) => ({
      render: () => `<strong data-testid="badge">${row().name}!</strong>`,
    }));
    render(DataTable, {
      columns: [{ key: "name", label: "Name", cell: badge }],
      data,
    });
    const badges = screen.getAllByTestId("badge");
    expect(badges).toHaveLength(3);
    expect(badges[0].textContent).toBe("Alice!");
  });

  it("treats render as text regardless of the function name", () => {
    // Antes, uma função chamada snippet* era tratada como snippet; o nome
    // não define o tipo (e muda com a minificação).
    const snippetIdade = (row) => `${row.age} anos`;
    render(DataTable, {
      columns: [{ key: "age", label: "Age", render: snippetIdade }],
      data,
    });
    expect(screen.getByText("30 anos")).toBeInTheDocument();
  });

  it("prefers cell over render when both are given", () => {
    const cell = createRawSnippet((row) => ({
      render: () => `<em>${row().name} (cell)</em>`,
    }));
    render(DataTable, {
      columns: [
        { key: "name", label: "Name", cell, render: (row) => `${row.name} (render)` },
      ],
      data,
    });
    expect(screen.getByText("Alice (cell)")).toBeInTheDocument();
    expect(screen.queryByText("Alice (render)")).not.toBeInTheDocument();
  });
});
