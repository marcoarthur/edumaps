import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
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
});
