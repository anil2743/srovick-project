import java.io.*;
import java.sql.*;
import jakarta.servlet.*;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import org.json.JSONArray;
import org.json.JSONObject;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

@WebServlet("/api/attendance/*")
public class AttendanceServlet extends HttpServlet {
    private static final String DB_URL = "jdbc:mysql://localhost:3306/cyedb?useTimezone=true&serverTimezone=Asia/Kolkata";
    private static final String DB_USER = "root";
    private static final String DB_PASS = "Anilp@2024";
    private static final ZoneId IST_ZONE = ZoneId.of("Asia/Kolkata");
    private static final DateTimeFormatter TIMESTAMP_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.sendRedirect(request.getContextPath() + "/attendance_register.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        String pathInfo = request.getPathInfo();
        if (pathInfo == null || (!pathInfo.equals("/check-in") && !pathInfo.equals("/checkout") && !pathInfo.equals("/break"))) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        String email = (session != null) ? (String) session.getAttribute("email") : null;
        if (email == null) {
            response.sendRedirect(request.getContextPath() + "/Login.jsp");
            return;
        }

        String date = request.getParameter("date");

        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASS)) {
                String userSql = "SELECT id FROM users WHERE email = ?";
                PreparedStatement userStmt = conn.prepareStatement(userSql);
                userStmt.setString(1, email);
                ResultSet rs = userStmt.executeQuery();
                if (!rs.next()) {
                    session.setAttribute("error", "User not found");
                    response.sendRedirect(request.getContextPath() + "/attendance_register.jsp");
                    return;
                }
                String userId = rs.getString("id");

                if (pathInfo.equals("/check-in")) {
                    String sql = "INSERT INTO attendance (user_id, date, check_in_time, attendance_status) " +
                                 "VALUES (?, ?, ?, 'Present')";
                    PreparedStatement stmt = conn.prepareStatement(sql);
                    stmt.setString(1, userId);
                    stmt.setString(2, date);
                    stmt.setTimestamp(3, getCurrentISTTimestamp());
                    stmt.executeUpdate();
                    session.setAttribute("message", "Check-in successful. Status: Working/Available");

                } else if (pathInfo.equals("/break")) {
                    String status = request.getParameter("status");
                    if (!"working".equals(status) && !"tea".equals(status) && !"lunch".equals(status) && 
                        !"personal".equals(status) && !"SERVER_DISCONNECT".equals(status)) {
                        session.setAttribute("error", "Invalid status.");
                        response.sendRedirect(request.getContextPath() + "/attendance_register.jsp");
                        return;
                    }

                    String sql = "SELECT check_in_time, check_out_time, break_log FROM attendance " +
                                 "WHERE user_id = ? AND date = ? AND check_out_time IS NULL";
                    PreparedStatement selectStmt = conn.prepareStatement(sql);
                    selectStmt.setString(1, userId);
                    selectStmt.setString(2, date);
                    ResultSet rsBreak = selectStmt.executeQuery();

                    if (rsBreak.next()) {
                        String breakLogJson = rsBreak.getString("break_log");
                        JSONArray breakLog = breakLogJson != null ? new JSONArray(breakLogJson) : new JSONArray();
                        JSONObject newBreak = new JSONObject();
                        Timestamp now = getCurrentISTTimestamp();

                        if ("working".equals(status)) {
                            for (int i = breakLog.length() - 1; i >= 0; i--) {
                                JSONObject breakEntry = breakLog.getJSONObject(i);
                                if (breakEntry.isNull("end")) {
                                    breakEntry.put("end", formatTimestampToIST(now));
                                    break;
                                }
                            }
                            session.setAttribute("message", "Returned to Working/Available.");
                        } else {
                            newBreak.put("type", status);
                            newBreak.put("start", formatTimestampToIST(now));
                            newBreak.put("end", JSONObject.NULL);
                            breakLog.put(newBreak);
                            session.setAttribute("message", 
                                status.equals("tea") ? "Tea/Coffee Break started." :
                                status.equals("lunch") ? "Lunch Break started." :
                                status.equals("personal") ? "Personal Break started." :
                                status.equals("SERVER_DISCONNECT") ? "Server disconnected." :
                                "Status updated.");
                        }

                        String updateSql = "UPDATE attendance SET break_log = ? WHERE user_id = ? AND date = ?";
                        PreparedStatement updateStmt = conn.prepareStatement(updateSql);
                        updateStmt.setString(1, breakLog.toString());
                        updateStmt.setString(2, userId);
                        updateStmt.setString(3, date);
                        updateStmt.executeUpdate();
                    } else {
                        session.setAttribute("error", "No active check-in found.");
                    }

                } else if (pathInfo.equals("/checkout")) {
                    String sql = "SELECT check_in_time, break_log FROM attendance " +
                                 "WHERE user_id = ? AND date = ? AND check_out_time IS NULL";
                    PreparedStatement selectStmt = conn.prepareStatement(sql);
                    selectStmt.setString(1, userId);
                    selectStmt.setString(2, date);
                    ResultSet rsCheckIn = selectStmt.executeQuery();

                    if (rsCheckIn.next()) {
                        Timestamp checkInTime = rsCheckIn.getTimestamp("check_in_time");
                        Timestamp checkOutTime = getCurrentISTTimestamp();
                        String breakLogJson = rsCheckIn.getString("break_log");
                        long totalBreakMillis = 0;

                        if (breakLogJson != null) {
                            JSONArray breakLog = new JSONArray(breakLogJson);
                            for (int i = breakLog.length() - 1; i >= 0; i--) {
                                JSONObject breakEntry = breakLog.getJSONObject(i);
                                if (breakEntry.isNull("end")) {
                                    breakEntry.put("end", formatTimestampToIST(checkOutTime));
                                    break;
                                }
                            }
                            for (int i = 0; i < breakLog.length(); i++) {
                                JSONObject breakEntry = breakLog.getJSONObject(i);
                                if (!breakEntry.isNull("start") && !breakEntry.isNull("end")) {
                                    Timestamp start = Timestamp.valueOf(breakEntry.getString("start"));
                                    Timestamp end = Timestamp.valueOf(breakEntry.getString("end"));
                                    totalBreakMillis += end.getTime() - start.getTime();
                                }
                            }
                            breakLogJson = breakLog.toString();
                        }

                        long totalMillis = checkOutTime.getTime() - checkInTime.getTime();
                        long effectiveMillis = totalMillis - totalBreakMillis;
                        double hours = effectiveMillis / (1000.0 * 60 * 60);
                        String totalBreakTime = formatMillisToTime(totalBreakMillis);

                        String status;
                        if (hours > 7.5) {
                            status = "Full Day";
                        } else if (hours > 4.0) {
                            status = "Half Day";
                        } else {
                            status = "Absent";
                        }

                        String updateSql = "UPDATE attendance SET check_out_time = ?, hours = ?, " +
                                         "attendance_status = ?, total_break_time = ?, break_log = ? " +
                                         "WHERE user_id = ? AND date = ?";
                        PreparedStatement updateStmt = conn.prepareStatement(updateSql);
                        updateStmt.setTimestamp(1, checkOutTime);
                        updateStmt.setDouble(2, hours);
                        updateStmt.setString(3, status);
                        updateStmt.setString(4, totalBreakTime);
                        updateStmt.setString(5, breakLogJson);
                        updateStmt.setString(6, userId);
                        updateStmt.setString(7, date);

                        updateStmt.executeUpdate();
                        session.setAttribute("message", "Check-out successful. You worked " + String.format("%.2f", hours) + " hours. Status: " + status);
                    } else {
                        session.setAttribute("error", "No active check-in found.");
                    }
                }

                response.sendRedirect(request.getContextPath() + "/attendance_register.jsp");

            }
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
            session.setAttribute("error", "JDBC Driver not found: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/attendance_register.jsp");
        } catch (SQLException e) {
            e.printStackTrace();
            session.setAttribute("error", "Database error: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/attendance_register.jsp");
        } catch (Exception e) {
            e.printStackTrace();
            session.setAttribute("error", "Error processing break log: " + e.getMessage());
            response.sendRedirect(request.getContextPath() + "/attendance_register.jsp");
        }
    }

    @Override
    protected void doPut(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        doPost(request, response);
    }

    private Timestamp getCurrentISTTimestamp() {
        ZonedDateTime istTime = ZonedDateTime.now(IST_ZONE);
        return Timestamp.from(istTime.toInstant());
    }

    private String formatTimestampToIST(Timestamp timestamp) {
        ZonedDateTime istTime = timestamp.toInstant().atZone(IST_ZONE);
        return istTime.format(TIMESTAMP_FORMATTER);
    }

    private String formatMillisToTime(long millis) {
        long hours = millis / (1000 * 60 * 60);
        long minutes = (millis / (1000 * 60)) % 60;
        long seconds = (millis / 1000) % 60;
        return String.format("%02d:%02d:%02d", hours, minutes, seconds);
    }
}