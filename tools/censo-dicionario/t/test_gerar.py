"""Testes do gerador do dicionário do Censo (tools/censo-dicionario/gerar.py).

Rodar da raiz do repositório:

    python3 -m unittest discover -s tools/censo-dicionario/t -v

Não dependem do xlsx do INEP: montam um mini-xlsx sintético com zipfile, no
mesmo layout do "Dicionário de Variáveis" (legenda nas linhas 1-3, cabeçalho
"Nome da Variável", linha de anos com 2 dígitos, coluna de notas detectada).
"""

import csv
import importlib.util
import io
import json
import os
import tempfile
import unittest
import zipfile
from xml.sax.saxutils import escape

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location('gerar', os.path.join(AQUI, '..', 'gerar.py'))
gerar = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gerar)


# --------------------------------------------------------------------------
# mini-xlsx
# --------------------------------------------------------------------------

def _letra(i):
    s = ''
    i += 1
    while i:
        i, r = divmod(i - 1, 26)
        s = chr(65 + r) + s
    return s


def _sheet_xml(linhas):
    """linhas: {nº linha: {letra: texto}} → sheetN.xml com inlineStr."""
    out = ['<?xml version="1.0" encoding="UTF-8"?>'
           '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
           '<sheetData>']
    for n in sorted(linhas):
        out.append('<row r="%d">' % n)
        for letra, val in sorted(linhas[n].items(), key=lambda kv: gerar.col_indice(kv[0])):
            out.append('<c r="%s%d" t="inlineStr"><is><t xml:space="preserve">%s</t></is></c>'
                       % (letra, n, escape(val)))
        out.append('</row>')
    out.append('</sheetData></worksheet>')
    return ''.join(out)


def mini_xlsx(caminho, abas):
    """abas: [(nome, {linha: {letra: texto}})]."""
    sheets = ''.join('<sheet name="%s" sheetId="%d" r:id="rId%d"/>' % (escape(n), i + 1, i + 1)
                     for i, (n, _) in enumerate(abas))
    rels = ''.join('<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/'
                   'officeDocument/2006/relationships/worksheet" Target="worksheets/sheet%d.xml"/>'
                   % (i + 1, i + 1) for i in range(len(abas)))
    with zipfile.ZipFile(caminho, 'w') as z:
        z.writestr('xl/workbook.xml',
                   '<?xml version="1.0" encoding="UTF-8"?>'
                   '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
                   'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
                   '<sheets>%s</sheets></workbook>' % sheets)
        z.writestr('xl/_rels/workbook.xml.rels',
                   '<?xml version="1.0" encoding="UTF-8"?>'
                   '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                   '%s</Relationships>' % rels)
        for i, (_, linhas) in enumerate(abas):
            z.writestr('xl/worksheets/sheet%d.xml' % (i + 1), _sheet_xml(linhas))


def aba_sintetica(anos, linhas_dados, col_notas=None):
    """Monta uma aba no layout do INEP. anos: [2019..2025]; linhas_dados:
    [(variavel, descricao, tipo, tam, categoria, {ano: 's'|'n'}, notas)]."""
    letras_anos = [_letra(6 + i) for i in range(len(anos))]  # G…
    col_notas = col_notas or _letra(6 + len(anos))
    l = {
        1: {'B': 'Alteração de nomenclatura ou metodologia de cálculo'},
        2: {'B': 'Variável nova'},
        3: {'B': 'Descontinuidade'},
        4: {'A': '   Dicionário de Variáveis - Tabela X'},
        7: {'A': 'N', 'B': 'Nome da Variável', 'C': 'Descrição da Variável', 'D': 'Tipo',
            'E': 'Tam.(1)', 'F': 'Categoria', 'G': 'Coleta por ano ("s"=sim;"n"=não ) ',
            col_notas: 'Notas Importantes'},
        8: {le: '%02d' % (a % 100) for le, a in zip(letras_anos, anos)},
    }
    for i, (var, desc, tipo, tam, cat, coleta, notas) in enumerate(linhas_dados):
        cel = {'A': str(i + 1), 'B': var, 'C': desc, 'D': tipo, 'E': tam}
        if cat:
            cel['F'] = cat
        for le, a in zip(letras_anos, anos):
            cel[le] = coleta.get(a, 's')
        if notas:
            cel[col_notas] = notas
        l[10 + i] = cel
    return l


# --------------------------------------------------------------------------

class ParseCategorias(unittest.TestCase):
    def test_codigos_simples(self):
        cats, na, livre = gerar.parse_categorias('1 - Federal\n2 - Estadual\n3 - Municipal\n4 - Privada')
        self.assertEqual(cats, {'1': 'Federal', '2': 'Estadual', '3': 'Municipal', '4': 'Privada'})
        self.assertEqual((na, livre), ('', ''))

    def test_nao_aplicavel_sem_codigo(self):
        cats, na, _ = gerar.parse_categorias(
            '1 - Particular\n2 - Comunitária\n   - Não aplicável para escolas públicas')
        self.assertEqual(list(cats), ['1', '2'])
        self.assertEqual(na, 'Não aplicável para escolas públicas')

    def test_nao_aplicavel_multilinha(self):
        cats, na, _ = gerar.parse_categorias(
            '1 - Próprio\n2 - Alugado\n   - Não aplicável para escolas que não ocupam prédio \n     escolar')
        self.assertEqual(cats, {'1': 'Próprio', '2': 'Alugado'})
        self.assertEqual(na, 'Não aplicável para escolas que não ocupam prédio escolar')

    def test_rotulo_multilinha(self):
        cats, _, _ = gerar.parse_categorias('1 - Contrato de consórcio público/Convênio de\n   cooperação\n2 - Outro')
        self.assertEqual(cats['1'], 'Contrato de consórcio público/Convênio de cooperação')
        self.assertEqual(cats['2'], 'Outro')

    def test_nove_nao_informado(self):
        cats, _, _ = gerar.parse_categorias('0 - Não\n1 - Sim\n9 - Não informado')
        self.assertEqual(cats['9'], 'Não informado')

    def test_codigo_normalizado_em_numerico(self):
        cats, _, _ = gerar.parse_categorias('01 - Um\n02 - Dois', numerico=True)
        self.assertEqual(list(cats), ['1', '2'])
        cats, _, _ = gerar.parse_categorias('01 - Um', numerico=False)
        self.assertEqual(list(cats), ['01'])

    def test_texto_livre(self):
        cats, na, livre = gerar.parse_categorias('Educação Profissional Não-Técnica')
        self.assertEqual((cats, na, livre), ({}, '', 'Educação Profissional Não-Técnica'))

    def test_vazio(self):
        self.assertEqual(gerar.parse_categorias(''), ({}, '', ''))
        self.assertEqual(gerar.parse_categorias(None), ({}, '', ''))

    def test_categoria_nas_notas(self):
        extras = gerar.categorias_das_notas('Em 2019:\nExiste adicionalmente a categoria "9 - Não informado".')
        self.assertEqual(extras, {'9': 'Não informado'})
        self.assertEqual(gerar.categorias_das_notas('sem categoria nenhuma'), {})


class Anos(unittest.TestCase):
    def test_faixas(self):
        self.assertEqual(gerar.faixas_anos([2007, 2008, 2009, 2010, 2011, 2014, 2015]), '2007-2011,2014-2015')
        self.assertEqual(gerar.faixas_anos([2019]), '2019')
        self.assertEqual(gerar.faixas_anos([2025, 2007, 2023, 2024]), '2007,2023-2025')
        self.assertEqual(gerar.faixas_anos([]), '')

    def test_ano_mudanca(self):
        notas = ('De 2007 a 2011:\n0 - Não se aplica\nDe 2012 a 2018:\n0 - Outra\n'
                 'Em 2023 foi adicionada a categoria 8:')
        self.assertEqual(gerar.ano_mudanca(notas, '2007'), 2023)
        self.assertEqual(gerar.ano_mudanca('Entre 2007 e 2021:\nA variável X foi renomeada', '2007'), 2022)
        # anos <= ano_inicio não contam
        self.assertIsNone(gerar.ano_mudanca('Em 2019:\nExiste adicionalmente a categoria', '2019'))
        self.assertIsNone(gerar.ano_mudanca('', '2007'))


class Abas(unittest.TestCase):
    def test_nome_aba(self):
        self.assertEqual(gerar.nome_aba('Tabela_de_Escola'), 'Escola')
        self.assertEqual(gerar.nome_aba('Tabela_de_Matrícula'), 'Matricula')
        self.assertEqual(gerar.nome_aba('Tabela_Curso_Técnico '), 'CursoTecnico')
        self.assertEqual(gerar.nome_aba('Tabela_de_Gestor'), 'Gestor')

    def test_mapa_tabelas(self):
        self.assertEqual(gerar.MAPA_TABELAS, {
            'Escola': 'clean.censo_escolas',
            'Matricula': 'clean.censo_matriculas',
            'Docente': 'clean.censo_docentes',
            'Gestor': 'clean.censo_gestor',
        })
        self.assertNotIn('Turma', gerar.MAPA_TABELAS)


class XlsxSintetico(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        anos = list(range(2007, 2026))
        escola = aba_sintetica(anos, [
            ('TP_DEPENDENCIA', 'Dependência Administrativa', 'Num', '1',
             '1 - Federal\n2 - Estadual\n3 - Municipal\n4 - Privada', {}, ''),
            ('TP_CATEGORIA_ESCOLA_PRIVADA', 'Categoria', 'Num', '1',
             '1 - Particular\n   - Não aplicável para escolas públicas', {}, ''),
            ('IN_MATERIAL_PED_JOGOS', 'Jogos', 'Num', '1', '0 - Não\n1 - Sim',
             {a: 'n' for a in range(2007, 2019)},
             'Em 2019:\nExiste adicionalmente a categoria "9 - Não informado".'),
            ('TP_CONVENIO_PODER_PUBLICO', 'Convênio', 'Num', '1', '1 - Municipal',
             {a: ('s' if 2008 <= a <= 2021 else 'n') for a in anos}, ''),
            ('IN_LOCAL_FUNC_X', 'Lacuna', 'Num', '1', '',
             {a: ('n' if a in (2012, 2013) else 's') for a in anos}, ''),
            ('QT_EQUIP_TV', 'TVs', 'Num', '8', '88888 - valor extremo', {}, ''),
        ])
        # Gestor: só 2019..2025 e notas em N (layout diferente do Escola).
        gestor = aba_sintetica(list(range(2019, 2026)), [
            ('NU_ANO_CENSO', 'Ano do Censo', 'Num', '4', '', {}, 'nota do gestor'),
        ], col_notas='N')
        self.xlsx = os.path.join(self.tmp.name, 'mini.xlsx')
        mini_xlsx(self.xlsx, [('Tabela_de_Escola', escola), ('Tabela_de_Gestor', gestor)])
        self.linhas = gerar.extrair(self.xlsx)
        self.por = {(l['aba'], l['variavel']): l for l in self.linhas}

    def test_variaveis_e_abas(self):
        self.assertEqual(len(self.linhas), 7)
        self.assertIn(('Gestor', 'nu_ano_censo'), self.por)
        self.assertEqual(self.por[('Gestor', 'nu_ano_censo')]['notas'], 'nota do gestor')
        self.assertEqual(self.por[('Gestor', 'nu_ano_censo')]['anos_coletados'], '2019-2025')

    def test_categorias_json(self):
        dep = self.por[('Escola', 'tp_dependencia')]
        self.assertEqual(json.loads(dep['categorias']),
                         {'1': 'Federal', '2': 'Estadual', '3': 'Municipal', '4': 'Privada'})
        cat = self.por[('Escola', 'tp_categoria_escola_privada')]
        self.assertEqual(cat['nao_aplicavel'], 'Não aplicável para escolas públicas')

    def test_nove_das_notas_entra_nas_categorias(self):
        jogos = self.por[('Escola', 'in_material_ped_jogos')]
        self.assertEqual(json.loads(jogos['categorias']), {'0': 'Não', '1': 'Sim', '9': 'Não informado'})
        self.assertEqual((jogos['ano_inicio'], jogos['ano_fim']), ('2019', ''))

    def test_faixas_e_fim(self):
        conv = self.por[('Escola', 'tp_convenio_poder_publico')]
        self.assertEqual((conv['anos_coletados'], conv['ano_inicio'], conv['ano_fim']),
                         ('2008-2021', '2008', '2021'))
        lac = self.por[('Escola', 'in_local_func_x')]
        self.assertEqual(lac['anos_coletados'], '2007-2011,2014-2025')

    def test_csv_deterministico(self):
        a = os.path.join(self.tmp.name, 'a')
        b = os.path.join(self.tmp.name, 'b')
        gerar.main([self.xlsx, '--saida', a])
        gerar.main([self.xlsx, '--saida', b])
        with open(os.path.join(a, gerar.CSV_NOME), 'rb') as fa, open(os.path.join(b, gerar.CSV_NOME), 'rb') as fb:
            self.assertEqual(fa.read(), fb.read())
        with open(os.path.join(a, gerar.CSV_NOME), encoding='utf-8') as f:
            self.assertEqual(next(csv.reader(f)), gerar.CSV_COLUNAS)

    def test_sql_do_csv_igual_ao_do_xlsx(self):
        saida = os.path.join(self.tmp.name, 's')
        sql1 = os.path.join(self.tmp.name, '1.sql')
        sql2 = os.path.join(self.tmp.name, '2.sql')
        gerar.main([self.xlsx, '--saida', saida, '--sql', sql1])
        gerar.main(['--csv', os.path.join(saida, gerar.CSV_NOME), '--sql', sql2])
        with open(sql1, encoding='utf-8') as f1, open(sql2, encoding='utf-8') as f2:
            self.assertEqual(f1.read(), f2.read())


class DominioSql(unittest.TestCase):
    def test_tp_com_categorias(self):
        dom, nota = gerar.dominio_sql('tp_aee', '{"0": "Não oferece", "1": "Não exclusivamente", "2": "Exclusivamente"}', 'Num', '1')
        self.assertEqual(json.loads(dom), {'0': 'Não oferece', '1': 'Não exclusivamente', '2': 'Exclusivamente'})
        self.assertIsNone(nota)

    def test_in_sem_categorias_binaria(self):
        dom, nota = gerar.dominio_sql('in_x', '', 'Num', '1')
        self.assertEqual(json.loads(dom), {'0': 'Não', '1': 'Sim'})
        self.assertIn('binário', nota)

    def test_in_sem_categorias_nao_binaria(self):
        dom, nota = gerar.dominio_sql('in_x', '', 'Char', '10')
        self.assertIsNone(dom)
        self.assertTrue(nota)

    def test_sentinela_nao_vira_dominio(self):
        dom, nota = gerar.dominio_sql('qt_equip_tv', '{"88888": "valor extremo"}', 'Num', '8')
        self.assertIsNone(dom)
        self.assertIn('88888', nota)

    def test_complemento_edumaps(self):
        dom, nota = gerar.dominio_sql('in_educ_amb_eixo', '{"0": "Não", "1": "Sim"}', 'Num', '1',
                                      tabela='clean.censo_escolas')
        self.assertIn('9', json.loads(dom))
        self.assertIn('ausente do dicionário do INEP', nota)

    def test_literal_sql_escapa_aspas(self):
        self.assertEqual(gerar._lit("D'Oeste"), "'D''Oeste'")
        self.assertEqual(gerar._lit(''), 'NULL')


if __name__ == '__main__':
    unittest.main()
