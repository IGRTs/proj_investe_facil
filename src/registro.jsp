<%@page import="java.sql.*" %>
<%
    // Retrieve parameters using the correct casing
    String vnome = request.getParameter("txtNome");
    String vsenha = request.getParameter("txtSenha");
    String vemail = request.getParameter("txtEmail");

    String database = "db_investe_facil";
    String endereco = "jdbc:mysql://localhost:3306/" + database;
    String usuario = "root";
    String senha = "";
    String driver = "com.mysql.jdbc.Driver";

    String sql = "INSERT INTO Usuarios (user_nome, user_senha, user_email) VALUES (?, ?, ?)";


    try { // Bloco para tratamento de erros
        Class.forName(driver);
        try (Connection conexao = DriverManager.getConnection(endereco, usuario, senha);
             PreparedStatement stm = conexao.prepareStatement(sql)) {
            
            stm.setString(1, vnome);
            stm.setString(2, vsenha);
            stm.setString(3, vemail);
            stm.execute();
            
            out.print("<h3>Dados gravados com sucesso!</h3>");
        }
    } catch (Exception e) {
        out.print("<h3>Erro ao gravar dados: </h3>" + e.getMessage());
        e.printStackTrace();
    }
%>
<br><br>
<a href='registro.html'>Voltar</a>