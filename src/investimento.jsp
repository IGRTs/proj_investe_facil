<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.text.DecimalFormat" %>
<%@ page import="java.text.DecimalFormatSymbols" %>
<%@ page import="java.util.Locale" %>
<%!
    private String formatCurrency(double valor) {
        DecimalFormatSymbols symbols = new DecimalFormatSymbols(new Locale("pt", "BR"));
        DecimalFormat fmt = new DecimalFormat("#,##0.00", symbols);
        return "R$ " + fmt.format(valor);
    }

    private String formatPercent(double valor) {
        DecimalFormatSymbols symbols = new DecimalFormatSymbols(new Locale("pt", "BR"));
        DecimalFormat fmt = new DecimalFormat("0.00", symbols);
        return fmt.format(valor).replace('.', ',') + "%";
    }

    private double parseDouble(String valor, double padrao) {
        try {
            return Double.parseDouble(valor.replace(',', '.'));
        } catch (Exception ex) {
            return padrao;
        }
    }
%>
<%
    request.setCharacterEncoding("UTF-8");

    String modalidade = request.getParameter("modalidade");
    if (modalidade == null || modalidade.trim().isEmpty()) {
        modalidade = "CDB";
    }

    double aporteInicial = parseDouble(request.getParameter("aporte_inicial"), 10000);
    double aportesMensais = parseDouble(request.getParameter("aportes_mensais"), 0);
    int prazo = 0;
    // o código tenta converter o valor do prazo para um número inteiro usando Integer.parseInt(). Se a conversão falhar (por exemplo, se o usuário deixar o campo vazio ou digitar um valor não numérico), o bloco catch captura a exceção e atribui o valor 0 à variável prazo. Isso garante que o código continue funcionando mesmo que o usuário não forneça um valor válido para o prazo, evitando erros de execução
    try {
        prazo = Integer.parseInt(request.getParameter("prazo"));
    } catch (Exception ignored) {
        prazo = 0;
    }
    String tipoPrazo = request.getParameter("tipo_prazo");
    if (tipoPrazo == null || tipoPrazo.trim().isEmpty()) {
        tipoPrazo = "Meses";
    }

    String tipoRentabilidade = request.getParameter("tipo_rentabilidade");
    if (tipoRentabilidade == null || tipoRentabilidade.trim().isEmpty()) {
        tipoRentabilidade = "Pos-fixado";
    }

    double taxaCdi = parseDouble(request.getParameter("taxa_cdi"), 10.5);
    double porcentagemCdi = parseDouble(request.getParameter("porcentagem_cdi"), 100);
    double taxaPrefixada = parseDouble(request.getParameter("taxa_prefixada"), 11);

    int meses = "Anos".equalsIgnoreCase(tipoPrazo) ? prazo * 12 : prazo;

    // o cálculo do valor bruto final da aplicação é feito usando a fórmula de juros compostos para o aporte inicial e a fórmula de valor futuro de uma série de pagamentos para os aportes mensais, considerando a taxa mensal equivalente à taxa anual dividida por 12. O código também trata os casos em que o prazo é zero ou a taxa mensal é muito próxima de zero para evitar erros de cálculo
    double jurosAnual = "Prefixado".equalsIgnoreCase(tipoRentabilidade)
            ? taxaPrefixada
            : (taxaCdi * porcentagemCdi / 100.0);

    double taxaMensal = jurosAnual / 100.0 / 12.0;
    double valorBruto;
    if (meses <= 0 || Math.abs(taxaMensal) < 1e-9) {
        valorBruto = aporteInicial + (aportesMensais * meses);
    } else {
        double fator = Math.pow(1.0 + taxaMensal, meses);
        valorBruto = aporteInicial * fator + aportesMensais * ((fator - 1.0) / taxaMensal);
    }

    double totalInvestido = aporteInicial + (aportesMensais * meses);
    double rendimentoBruto = Math.max(0, valorBruto - totalInvestido);

    // o cálculo do imposto de renda é feito com base na tabela regressiva, onde a alíquota diminui conforme o prazo da aplicação aumenta. O código converte o prazo para dias (considerando 30 dias por mês) e aplica as regras para determinar a alíquota correta. Em seguida, calcula o valor do IR sobre o rendimento bruto e o valor líquido final da aplicação após a dedução do imposto
    int dias = meses * 30;
    double aliquotaIr = 0.225;
    if (dias > 180) aliquotaIr = 0.20;
    if (dias > 360) aliquotaIr = 0.175;
    if (dias > 720) aliquotaIr = 0.15;

    // o valor do IR é calculado sobre o rendimento bruto, ou seja, o ganho total da aplicação, e não sobre o valor total investido ou o valor bruto final
    double valorIr = rendimentoBruto * aliquotaIr;
    double valorLiquido = valorBruto - valorIr;
    double rendimentoLiquido = Math.max(0, valorLiquido - totalInvestido);

    // variável para controlar se a simulação foi salva no banco de dados ou não, e uma mensagem para exibir o resultado da tentativa de salvar a simulação, seja sucesso ou erro
    boolean salvoNoBanco = false;
    String mensagem = "";
    Integer codUsuario = (Integer) session.getAttribute("codUsuario");

    // somente tenta salvar a simulação no banco de dados se o método da requisição for POST, ou seja, quando o formulário for submetido. Isso evita que a simulação seja salva apenas por acessar a página ou atualizar o navegador
    if (request.getMethod().equalsIgnoreCase("POST")) {
        if (codUsuario == null) {
            mensagem = "Faça login para salvar a simulação no banco de dados.";
        } else {
            String database = "db_investe_facil";
            String endereco = "jdbc:mysql://localhost:3306/" + database;
            String usuario = "root";
            String senha = "";
            String driver = "com.mysql.jdbc.Driver";
            String sql = "INSERT INTO investimento (cod_usuario, fundos, aportes_mensais, modalidade, periodo_aplicacao, tipo_prazo, tipo_rentabilidade, taxa_cdi, porcentagem_cdi, juros, rendimento) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

            // o código para salvar a simulação no banco de dados é colocado dentro de um bloco try-catch para tratar possíveis erros que possam ocorrer durante a conexão com o banco ou a execução da query. Se a simulação for salva com sucesso, a variável salvoNoBanco é setada como true e a mensagem de sucesso é atribuída à variável mensagem. Caso ocorra algum erro, a mensagem de erro é atribuída à variável mensagem para que possa ser exibida ao usuário posteriormente
            try {
                Class.forName(driver);
                try (Connection conexao = DriverManager.getConnection(endereco, usuario, senha);
                     PreparedStatement stm = conexao.prepareStatement(sql)) {
                    stm.setInt(1, codUsuario);
                    stm.setDouble(2, aporteInicial);
                    stm.setDouble(3, aportesMensais);
                    stm.setString(4, modalidade);
                    stm.setInt(5, prazo);
                    stm.setString(6, tipoPrazo);
                    stm.setString(7, tipoRentabilidade);
                    stm.setDouble(8, taxaCdi);
                    stm.setDouble(9, porcentagemCdi);
                    stm.setDouble(10, jurosAnual);
                    stm.setDouble(11, rendimentoBruto);
                    stm.executeUpdate();
                    salvoNoBanco = true;
                    mensagem = "Simulação salva com sucesso.";
                }
            } catch (Exception e) {
                mensagem = "Erro ao salvar a simulação: " + e.getMessage();
            }
        }
    }
%>
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Simulador de Investimentos</title>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body class="relative min-h-screen bg-gray-100 flex items-center justify-center p-6">
    <div class="absolute top-4 left-4 z-10">
      <a href="index.jsp" class="inline-flex items-center gap-3 rounded-full bg-white px-4 py-2 shadow-md transition hover:bg-gray-50">
        <span class="flex h-9 w-9 items-center justify-center rounded-full bg-blue-100 text-blue-700">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="h-5 w-5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
        </span>
        <span class="text-base font-semibold text-gray-800">Voltar ao Menu</span>
      </a>
    </div>

    <div class="absolute top-4 right-4 z-10 flex items-center gap-3">
      <% if (session.getAttribute("logado") != null && (Boolean) session.getAttribute("logado")) { %>
        <span class="rounded-full bg-white px-4 py-2 text-sm font-medium text-gray-800 shadow-md">Olá, <%= session.getAttribute("usuarioNome") %></span>
        <a href="logout.jsp" class="rounded-full bg-red-500 px-4 py-2 text-sm font-semibold text-white shadow-md transition hover:bg-red-600">Sair</a>
      <% } else { %>
        <a href="login.html" class="rounded-full bg-blue-600 px-4 py-2 text-sm font-semibold text-white shadow-md transition hover:bg-blue-700">Entrar</a>
      <% } %>
    </div>

    <div class="w-full max-w-6xl pt-12">
      <div class="grid gap-6 lg:grid-cols-[1.05fr_0.95fr]">
        <section class="rounded-3xl bg-white p-6 shadow-xl ring-1 ring-gray-200 md:p-8">
          <div class="flex items-center gap-3">
            <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-blue-100 text-blue-700">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="h-6 w-6">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3 18h18M7 15l3-3 3 2 4-6" />
              </svg>
            </div>
            <div>
              <h1 class="text-2xl font-semibold text-gray-900">Simulador de investimentos</h1>
              <p class="text-sm text-gray-500">Preencha os dados e clique em calcular para ver a simulação.</p>
            </div>
          </div>

          <form method="post" action="investimento.jsp" class="mt-6 space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Tipo de investimento</label>
              <div class="grid gap-3 rounded-2xl border border-gray-200 bg-gray-50 p-3 sm:grid-cols-2">
                <label class="flex cursor-pointer items-center gap-2 rounded-xl bg-white px-3 py-2 shadow-sm ring-1 ring-gray-200">
                  <input type="radio" name="modalidade" value="CDB" <%= "CDB".equals(modalidade) ? "checked" : "" %> class="h-4 w-4 text-blue-600 focus:ring-blue-500" />
                  <span class="text-sm text-gray-700">CDB</span>
                </label>
                <label class="flex cursor-pointer items-center gap-2 rounded-xl bg-white px-3 py-2 shadow-sm ring-1 ring-gray-200">
                  <input type="radio" name="modalidade" value="CDI" <%= "CDI".equals(modalidade) ? "checked" : "" %> class="h-4 w-4 text-blue-600 focus:ring-blue-500" />
                  <span class="text-sm text-gray-700">CDI</span>
                </label>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Valor inicial (aporte)</label>
              <input name="aporte_inicial" type="number" step="0.01" min="0" value="<%= aporteInicial %>" class="w-full rounded-md border border-gray-300 px-4 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-400" />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Aportes mensais</label>
              <input name="aportes_mensais" type="number" step="0.01" min="0" value="<%= aportesMensais %>" class="w-full rounded-md border border-gray-300 px-4 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-400" />
              <p class="mt-1 text-xs text-gray-500">Campo opcional para contribuições mensais.</p>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Prazo</label>
              <div class="grid gap-3 sm:grid-cols-[1fr_0.8fr]">
                <input name="prazo" type="number" min="1" value="<%= prazo %>" class="w-full rounded-md border border-gray-300 px-4 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-400" />
                <select name="tipo_prazo" class="w-full rounded-md border border-gray-300 bg-white px-4 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-400">
                  <option value="Meses" <%= "Meses".equalsIgnoreCase(tipoPrazo) ? "selected" : "" %>>Meses</option>
                  <option value="Anos" <%= "Anos".equalsIgnoreCase(tipoPrazo) ? "selected" : "" %>>Anos</option>
                </select>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Tipo de rentabilidade</label>
              <div class="grid gap-3 rounded-2xl border border-gray-200 bg-gray-50 p-3 sm:grid-cols-2">
                <label class="flex cursor-pointer items-center gap-2 rounded-xl bg-white px-3 py-2 shadow-sm ring-1 ring-gray-200">
                  <input type="radio" name="tipo_rentabilidade" value="Pos-fixado" <%= "Pos-fixado".equalsIgnoreCase(tipoRentabilidade) ? "checked" : "" %> class="h-4 w-4 text-blue-600 focus:ring-blue-500" />
                  <span class="text-sm text-gray-700">Pós-fixado (CDI)</span>
                </label>
                <label class="flex cursor-pointer items-center gap-2 rounded-xl bg-white px-3 py-2 shadow-sm ring-1 ring-gray-200">
                  <input type="radio" name="tipo_rentabilidade" value="Prefixado" <%= "Prefixado".equalsIgnoreCase(tipoRentabilidade) ? "checked" : "" %> class="h-4 w-4 text-blue-600 focus:ring-blue-500" />
                  <span class="text-sm text-gray-700">Prefixado</span>
                </label>
              </div>
            </div>

            <div class="rounded-2xl border border-blue-100 bg-blue-50 p-4 space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Taxa CDI atual (%)</label>
                <input name="taxa_cdi" type="number" step="0.01" min="0" value="<%= taxaCdi %>" class="w-full rounded-md border border-gray-300 px-4 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-400" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Porcentagem do CDI (%)</label>
                <input name="porcentagem_cdi" type="number" step="0.1" min="0" value="<%= porcentagemCdi %>" class="w-full rounded-md border border-gray-300 px-4 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-400" />
                <p class="mt-1 text-xs text-gray-500">Use 100% para o rendimento padrão do CDI.</p>
              </div>
            </div>

            <div class="rounded-2xl border border-amber-100 bg-amber-50 p-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Taxa prefixada anual (%)</label>
              <input name="taxa_prefixada" type="number" step="0.01" min="0" value="<%= taxaPrefixada %>" class="w-full rounded-md border border-gray-300 px-4 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-400" />
              <p class="mt-1 text-xs text-gray-500">Usada quando a rentabilidade for prefixada.</p>
            </div>

            <button type="submit" class="w-full inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-blue-700">Calcular Simulação</button>
          </form>
        </section>

        <aside class="rounded-3xl bg-white p-6 shadow-xl ring-1 ring-gray-200 md:p-8">
          <div class="flex items-center gap-3">
            <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-emerald-100 text-emerald-700">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="h-6 w-6">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v18M6 9c1.5-1.5 3-2.5 6-2.5s4.5 1 6 2.5" />
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 15c1.5 1.5 3 2.5 6 2.5s4.5-1 6-2.5" />
              </svg>
            </div>
            <div>
              <h2 class="text-xl font-semibold text-gray-900">Resultados da simulação</h2>
              <p class="text-sm text-gray-500">Cálculo com base no aporte, prazo, taxa e IR.</p>
            </div>
          </div>

          <% if (!mensagem.isEmpty()) { %>
            <div class="mt-6 rounded-2xl border <%= salvoNoBanco ? "border-emerald-200 bg-emerald-50 text-emerald-800" : "border-amber-200 bg-amber-50 text-amber-800" %> p-4 text-sm">
              <%= mensagem %>
            </div>
          <% } %>

          <div class="mt-6 space-y-4">
            <article class="rounded-2xl border border-blue-100 bg-blue-50 p-4">
              <p class="text-xs uppercase tracking-[0.2em] text-blue-700">Valor total bruto</p>
              <p class="mt-2 text-2xl font-semibold text-blue-900"><%= formatCurrency(valorBruto) %></p>
            </article>
            <article class="rounded-2xl border border-emerald-100 bg-emerald-50 p-4">
              <p class="text-xs uppercase tracking-[0.2em] text-emerald-700">Alíquota de IR</p>
              <p class="mt-2 text-2xl font-semibold text-emerald-700"><%= formatPercent(aliquotaIr * 100) %></p>
            </article>
            <article class="rounded-2xl border border-violet-100 bg-violet-50 p-4">
              <p class="text-xs uppercase tracking-[0.2em] text-violet-700">Valor descontado de IR</p>
              <p class="mt-2 text-2xl font-semibold text-violet-700"><%= formatCurrency(valorIr) %></p>
            </article>
            <article class="rounded-2xl border border-amber-100 bg-amber-50 p-4">
              <p class="text-xs uppercase tracking-[0.2em] text-amber-700">Valor líquido</p>
              <p class="mt-2 text-xl font-semibold text-amber-800"><%= formatCurrency(valorLiquido) %></p>
              <p class="mt-2 text-xs text-amber-700">Rendimento líquido: <strong><%= formatCurrency(rendimentoLiquido) %></strong></p>
              <p class="mt-1 text-xs text-amber-700">Taxa anual estimada: <strong><%= formatPercent(jurosAnual) %></strong></p>
              <p class="mt-1 text-xs text-amber-700">Prazo total: <strong><%= meses %> meses</strong></p>
            </article>
          </div>

          <p class="mt-6 text-sm text-gray-500">Os valores são calculados no JSP e, quando você estiver logado, também são salvos na tabela de investimentos.</p>
        </aside>
      </div>
    </div>
  </body>
</html>
