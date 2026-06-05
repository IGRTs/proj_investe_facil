<%@page import="java.sql.*" %>
<%
    String vsenha = request.getParameter("txtSenha");
    String vemail = request.getParameter("txtEmail");
    String database = "db_investe_facil";
    String endereco = "jdbc:mysql://localhost:3306/" + database;
    String usuario = "root";
    String senha = "";
    String driver = "com.mysql.jdbc.Driver";
    String sql = "SELECT * FROM Usuarios WHERE user_email = ? AND user_senha = ?";

    try {
        Class.forName(driver);
        try (Connection conexao = DriverManager.getConnection(endereco, usuario, senha);
             PreparedStatement stm = conexao.prepareStatement(sql)) {

            stm.setString(1, vemail);
            stm.setString(2, vsenha);

            // colocamos o resultado da query dentro de uma variável do tipo ResultSet para que possamos ler os dados retornados usando os métodos getString(), getInt(), etc. que são metodos da classe ResultSet
            ResultSet dados = stm.executeQuery();

            if (dados.next()) {
                // linha encontrada — agora podemos ler os dados usando os métodos getString(), getInt(), etc. da classe ResultSet

                String vnome = dados.getString("user_nome");

                // salva os dados na sessão
                session.setAttribute("usuarioEmail", vemail);
                session.setAttribute("usuarioNome", vnome);
                session.setAttribute("logado", true);

                // redireciona para a página principal
                response.sendRedirect("index.html");
            } else {
                // nenhuma linha encontrada — ou seja, email e senha não correspondem a nenhum registro no banco
                out.print("<h3>Usuário ou senha inválidos!</h3>");
            }
        }
    } catch (Exception e) {
        out.print("<h3>Erro!</h3>" + e.getMessage());
        e.printStackTrace();
    }
%>