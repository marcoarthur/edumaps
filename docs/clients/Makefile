PANDOC := pandoc --pdf-engine=weasyprint --toc --toc-depth=2 --metadata lang=pt-BR

PDFS := gestor/potencial.pdf privado/setor.pdf

.PHONY: pdf gestor setor clean

pdf: $(PDFS)

gestor: gestor/potencial.pdf

setor: privado/setor.pdf

gestor/potencial.pdf: gestor/potencial.md
	$(PANDOC) --metadata title="EduMaps — A educação da sua escola em um painel" $< -o $@

privado/setor.pdf: privado/setor.md
	$(PANDOC) --metadata title="EduMaps — O setor educacional brasileiro como mercado de dados" $< -o $@

clean:
	rm -f $(PDFS)