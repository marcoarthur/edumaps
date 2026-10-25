# help-wiki

Ferramentas para validar e exportar `docs/ajuda/` para wiki.

## Uso
```bash
python3 tools/help-wiki/export.py
```

Valida:
- Front-matter obrigatório
- Enums (`publico/modulo/nivel/status`)
- `funcionalidade` resolvível
- `status: parcial` requer seção "Limitações conhecidas"

Local, fora do deploy.
