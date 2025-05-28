<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.SQLException" %>
<%@ page import="org.json.*" %>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Attendance Register</title>
    <link href="https://cdn.tailwindcss.com" rel="stylesheet">
    <style>
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .card { background: white; border-radius: 12px; box-shadow: 0 6px 12px rgba(0,0,0,0.1); padding: 24px; }
        .btn { width: 100%; padding: 12px; border-radius: 8px; color: white; font-weight: bold; transition: all 0.3s; }
        .btn-connect { background: #2563eb; }
        .btn-disconnect { background: #dc2626; }
        .btn-checkin { background: #16a34a; }
        .btn-checkout { background: #dc2626; }
        .btn-disabled { background: #d1d5db; cursor: not-allowed; opacity: 0.6; }
        .select-status { width: 100%; padding: 12px; border-radius: 8px; border: 1px solid #d1d5db; margin-bottom: 16px; font-size: 16px; }
        .status-indicator { display: inline-flex; align-items: center; padding: 8px 16px; border-radius: 20px; font-size: 14px; }
        .status-connected { background: #dcfce7; color: #15803d; }
        .status-disconnected { background: #fee2e2; color: #b91c1c; }
        .animate-pulse { animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite; }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
    </style>
</head>
<body class="bg-gray-100">

<%
    String email = (String) session.getAttribute("email");
    if (email == null) {
        response.sendRedirect("Login.jsp");
        return;
    }

    String contextPath = request.getContextPath();
    String dbError = null;
    boolean alreadyCheckedIn = false;
    boolean alreadyCheckedOut = false;
    String currentStatus = "Not Checked In";

    java.sql.Connection conn = null;
    java.sql.PreparedStatement stmt = null;
    java.sql.ResultSet rs = null;

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = java.sql.DriverManager.getConnection("jdbc:mysql://localhost:3306/cyedb", "root", "Anilp@2024");
        String sql = "SELECT check_in_time, check_out_time, break_log FROM attendance a " +
                     "JOIN users u ON a.user_id = u.id " +
                     "WHERE u.email = ? AND a.date = CURDATE()";
        stmt = conn.prepareStatement(sql);
        stmt.setString(1, email);
        rs = stmt.executeQuery();
        if (rs.next()) {
            alreadyCheckedIn = rs.getTimestamp("check_in_time") != null;
            alreadyCheckedOut = rs.getTimestamp("check_out_time") != null;
            String breakLog = rs.getString("break_log");
            if (alreadyCheckedIn && !alreadyCheckedOut) {
                currentStatus = "working";
                if (breakLog != null && !breakLog.isEmpty()) {
                    try {
                        JSONArray breakLogArray = new JSONArray(breakLog);
                        for (int i = breakLogArray.length() - 1; i >= 0; i--) {
                            JSONObject breakEntry = breakLogArray.getJSONObject(i);
                            if (breakEntry.isNull("end")) {
                                currentStatus = breakEntry.getString("type");
                                break;
                            }
                        }
                    } catch (JSONException e) {
                        dbError = "Error parsing break log: " + e.getMessage();
                    }
                }
            }
        }
    } catch (ClassNotFoundException e) {
        dbError = "JDBC Driver not found: " + e.getMessage();
        e.printStackTrace();
    } catch (SQLException e) {
        dbError = "Database error: " + e.getMessage();
        e.printStackTrace();
    } finally {
        if (rs != null) try { rs.close(); } catch (SQLException e) {}
        if (stmt != null) try { stmt.close(); } catch (SQLException e) {}
        if (conn != null) try { conn.close(); } catch (SQLException e) {}
    }
%>

<div class="container">
    <div class="card">
        <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-800">Attendance</h1>
            <span id="wifiStatus" class="status-indicator status-disconnected">Disconnected</span>
        </div>
        <p class="text-gray-600 mb-6">
            <%= new java.text.SimpleDateFormat("EEEE, MMMM d, yyyy").format(new java.util.Date()) %>
        </p>

        <button id="connectButton" class="btn btn-connect" onclick="toggleConnection()">Connect to Server</button>

        <% if (!alreadyCheckedIn) { %>
            <form id="checkinForm" action="<%= contextPath %>/api/attendance/check-in" method="post" class="mt-4">
                <input type="hidden" name="date" value="<%= new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()) %>">
                <button id="checkinButton" type="submit" class="btn btn-checkin btn-disabled mt-2" disabled>Check In</button>
            </form>
        <% } else if (!alreadyCheckedOut) { %>
            <form id="statusForm" action="<%= contextPath %>/api/attendance/break" method="post" class="mt-4">
                <input type="hidden" name="date" value="<%= new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()) %>">
                <select id="statusSelect" name="status" class="select-status" onchange="submitStatusForm(this)" disabled>
                    <option value="" disabled <%= currentStatus.equals("Not Checked In") ? "selected" : "" %>>Select Status</option>
                    <option value="working" <%= currentStatus.equals("working") ? "selected" : "" %>>Working/Available</option>
                    <option value="tea" <%= currentStatus.equals("tea") ? "selected" : "" %>>Tea/Coffee Break</option>
                    <option value="lunch" <%= currentStatus.equals("lunch") ? "selected" : "" %>>Lunch Break</option>
                    <option value="personal" <%= currentStatus.equals("personal") ? "selected" : "" %>>Personal Break</option>
                </select>
            </form>
            <form id="checkoutForm" action="<%= contextPath %>/api/attendance/checkout" method="post" class="mt-4">
                <input type="hidden" name="date" value="<%= new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()) %>">
                <button id="checkoutButton" type="submit" class="btn btn-checkout btn-disabled" disabled>Check Out</button>
            </form>
        <% } else { %>
            <button type="button" class="btn btn-disabled mt-4" disabled>Attendance Completed</button>
        <% } %>

        <div class="mt-6 p-4 bg-gray-50 rounded-lg">
            <% if (alreadyCheckedIn && alreadyCheckedOut) { %>
                <p class="text-green-600 font-medium">✓ Attendance completed for today.</p>
            <% } else if (alreadyCheckedIn) { %>
                <p class="text-yellow-600 font-medium">Current status: 
                    <%= currentStatus.equals("working") ? "Working/Available" : 
                       currentStatus.equals("tea") ? "Tea/Coffee Break" : 
                       currentStatus.equals("lunch") ? "Lunch Break" : 
                       currentStatus.equals("personal") ? "Personal Break" : 
                       currentStatus.equals("SERVER_DISCONNECT") ? "Server Disconnected" : "Unknown" %>
                </p>
            <% } else { %>
                <p class="text-blue-600 font-medium">Please mark your attendance.</p>
            <% } %>
        </div>

        <%
            String message = (String) session.getAttribute("message");
            String error = (String) session.getAttribute("error");
            if (message != null) {
        %>
            <p class="text-green-500 mt-4 p-2 bg-green-50 rounded"><%= message %></p>
        <%
                session.removeAttribute("message");
            } else if (error != null) {
        %>
            <p class="text-red-500 mt-4 p-2 bg-red-50 rounded"><%= error %></p>
        <%
                session.removeAttribute("error");
            } else if (dbError != null) {
        %>
            <p class="text-red-500 mt-4 p-2 bg-red-50 rounded"><%= dbError %></p>
        <% } %>
    </div>
</div>

<script>
    const ssid = "CYETECH-5G";
    const password = "Cye@0987";
    const alreadyCheckedIn = <%= alreadyCheckedIn %>;
    const alreadyCheckedOut = <%= alreadyCheckedOut %>;
    let isConnected = false;
    let autoDisconnectTimeout;

    function toggleConnection() {
        if (isConnected) {
            disconnectFromServer();
        } else {
            connectToServer();
        }
    }

    function connectToServer() {
        const connectButton = document.getElementById('connectButton');
        connectButton.disabled = true;
        connectButton.textContent = 'Connecting...';
        connectButton.classList.add('animate-pulse');

        if (window.Android) {
            window.Android.connectToWiFi(ssid, password);
        } else {
            showError('Native interface not available. Please use the mobile app.');
            resetConnectButton();
        }
    }

    function disconnectFromServer() {
        if (window.Android) {
            window.Android.disconnectFromWiFi(ssid);
        }
    }

    function resetConnectButton() {
        const connectButton = document.getElementById('connectButton');
        connectButton.disabled = false;
        connectButton.textContent = 'Connect to Server';
        connectButton.classList.remove('animate-pulse');
        connectButton.classList.remove('btn-disconnect');
        connectButton.classList.add('btn-connect');
    }

    function showError(message) {
        alert(message);
    }

    function onWiFiConnected() {
        isConnected = true;
        const connectButton = document.getElementById('connectButton');
        connectButton.disabled = false;
        connectButton.textContent = 'Disconnect from Server';
        connectButton.classList.remove('animate-pulse');
        connectButton.classList.remove('btn-connect');
        connectButton.classList.add('btn-disconnect');
        
        document.getElementById('wifiStatus').textContent = 'Connected';
        document.getElementById('wifiStatus').classList.remove('status-disconnected');
        document.getElementById('wifiStatus').classList.add('status-connected');

        if (!alreadyCheckedIn) {
            document.getElementById('checkinButton').disabled = false;
            document.getElementById('checkinButton').classList.remove('btn-disabled');
        } else if (!alreadyCheckedOut) {
            document.getElementById('statusSelect').disabled = false;
            document.getElementById('checkoutButton').disabled = false;
            document.getElementById('checkoutButton').classList.remove('btn-disabled');
        }

        // Start 5-minute auto-disconnect timer
        resetAutoDisconnectTimer();
    }

    function onWiFiDisconnected() {
        isConnected = false;
        document.getElementById('wifiStatus').textContent = 'Disconnected';
        document.getElementById('wifiStatus').classList.remove('status-connected');
        document.getElementById('wifiStatus').classList.add('status-disconnected');

        if (!alreadyCheckedIn) {
            document.getElementById('checkinButton').disabled = true;
            document.getElementById('checkinButton').classList.add('btn-disabled');
        } else if (!alreadyCheckedOut) {
            document.getElementById('statusSelect').disabled = true;
            document.getElementById('checkoutButton').disabled = true;
            document.getElementById('checkoutButton').classList.add('btn-disabled');
        }

        resetConnectButton();
        clearAutoDisconnectTimer();
    }

    function onWiFiConnectionFailed() {
        showError('Failed to connect to WiFi.');
        resetConnectButton();
    }

    function resetAutoDisconnectTimer() {
        clearAutoDisconnectTimer();
        autoDisconnectTimeout = setTimeout(() => {
            disconnectFromServer();
        }, 5 * 60 * 1000); // 5 minutes
    }

    function clearAutoDisconnectTimer() {
        if (autoDisconnectTimeout) {
            clearTimeout(autoDisconnectTimeout);
            autoDisconnectTimeout = null;
        }
    }

    function submitStatusForm(select) {
        if (select.value && isConnected) {
            resetAutoDisconnectTimer();
            document.getElementById('statusForm').submit();
        }
    }

    // Handle form submissions to disconnect after check-in/checkout
    document.getElementById('checkinForm')?.addEventListener('submit', () => {
        if (isConnected) {
            setTimeout(() => disconnectFromServer(), 1000);
        }
    });

    document.getElementById('checkoutForm')?.addEventListener('submit', () => {
        if (isConnected) {
            setTimeout(() => disconnectFromServer(), 1000);
        }
    });
</script>
</body>
</html>