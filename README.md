# proj_investe_facil

Projeto para faculdade de uma plataforma com sistemas de login e registro simples para realizar operações de cálculo de investimentos.

## Requisitos

- Node.js e npm instalados
- XAMPP com Tomcat ou Apache Tomcat instalado para executar JSP
- Git para clonar o repositório

## Instalação

1. Clone o repositório:

```powershell
git clone https://github.com/IGRTs/proj_investe_facil.git
cd proj_investe_facil
```

2. Instale as dependências do Node:

```powershell
npm install
```

3. Rode o Tailwind em modo de desenvolvimento:

```powershell
npm run dev
```

Isso compila `src/input.css` para `src/output.css` e mantém a geração de CSS atualizada enquanto você altera os arquivos.

## Uso com XAMPP / Tomcat

1. Copie a pasta do projeto para o diretório de webapps do Tomcat, por exemplo:
   - `C:\xampp\tomcat\webapps\proj_investe_facil`
2. Reinicie o Tomcat pelo painel do XAMPP.
3. Abra no navegador:
   - `http://localhost:8080/proj_investe_facil/src/login.html`

> Se você usar outro servidor Tomcat, ajuste o caminho de deploy e a porta conforme necessário.

## Observações

- Não inclua `node_modules/` no Git.
- Se `src/output.css` estiver no `.gitignore`, execute `npm run dev` antes de abrir o site para gerar o CSS.
- O arquivo `src/input.css` é o arquivo fonte do Tailwind; o `src/output.css` é gerado automaticamente.
