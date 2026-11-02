---
titulo: "Configurações da plataforma"
publico: [administrador]
modulo: administrador
nivel: intermediario
status: ativo
relacionadas: [painel-de-administracao]
funcionalidade: ../../funcionalidades/plataforma/painel-configuracao.md
ultima_revisao: 2026-11-02
---

# Configurações da plataforma

> **Para quem:** Administrador  
> **Tempo de leitura:** ~4 min

## Em 30 segundos
Gerencie configurações gerais da plataforma com cautela.

## Passo a passo
1. **Onde ir:** Administração → Configurações
2. **Revisar** parâmetros antes de alterar
3. **Salvar** e validar impacto
4. **Documentar** alteração se relevante

## Roteiro desta página

Na primeira vez que o painel carrega (com perfil de administrador), um roteiro
de 3 passos mostra as categorias (com o selo “Em breve” no que ainda não está
disponível), como editar, validar e salvar um item (chaves secretas nunca são
exibidas) e as versões do termo de consentimento. Reabra pelo **?** do menu.

A página **Versões do consentimento** tem um roteiro próprio, de 2 passos: a
lista (vigente, rascunhos e arquivadas; cada inscrição guarda a versão que
aceitou) e como criar um rascunho e publicá-lo. Publicar arquiva a versão
vigente, e a publicada não pode mais ser alterada.

## Ativar o “Esqueci minha senha” dos gestores

O link **Esqueci minha senha** só aparece para os gestores quando o envio de
e-mail está pronto. Em **Canais de comunicação → E-mail (SMTP)**, preencha:

- servidor, remetente e **Canal e-mail ativado**;
- **URL pública da plataforma**: o endereço que as pessoas usam para abrir o
  EduMaps (ex.: `https://edumaps.exemplo.org`). Ele vai dentro do link do
  e-mail; sem ele, o link fica escondido.

## Limitações conhecidas
- Alterações podem afetar toda a plataforma.
- Nem todas as configurações são reversíveis imediatamente.

## Privacidade
Não exponha chaves/secrets em documentação pública.

## Veja também
- [Painel de administração](painel-de-administracao.md)
