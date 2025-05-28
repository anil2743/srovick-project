import jakarta.servlet.*;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.*;
import java.sql.*;

@WebServlet("/api/login")
public class LoginServlet extends HttpServlet {
    private static final String DB_URL = "jdbc:mysql://localhost:3306/cyedb";
    private static final String DB_USER = "root";
    private static final String DB_PASS = "Anilp@2024";

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String email = request.getParameter("email");
        String password = request.getParameter("password");
        HttpSession session = request.getSession();

        try {
            // Load JDBC driver
            Class<?> driverClass = Class.forName("com.mysql.cj.jdbc.Driver");
            System.out.println("Loaded JDBC Driver: " + driverClass.getName());

            try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {
                String sql = "SELECT id, name FROM users WHERE email = ? AND password = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                    stmt.setString(1, email);
                    stmt.setString(2, password); // 🔒 Tip: replace with hashed password comparison later

                    try (ResultSet rs = stmt.executeQuery()) {
                        if (rs.next()) {
                            session.setAttribute("email", email);
                            session.setAttribute("userId", rs.getInt("id"));
                            session.setAttribute("name", rs.getString("name"));
                            response.sendRedirect(request.getContextPath() + "/attendance_register.jsp");
                        } else {
                            session.setAttribute("error", "Invalid email or password");
                            response.sendRedirect(request.getContextPath() + "/Login.jsp");
                        }
                    }
                }
            }
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
            session.setAttribute("error", "JDBC Driver not found: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/Login.jsp");
        } catch (SQLException e) {
            e.printStackTrace();
            session.setAttribute("error", "Database error: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/Login.jsp");
        }
    }
}
