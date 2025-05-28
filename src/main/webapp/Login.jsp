<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Login</title>
    <link href="https://cdn.tailwindcss.com" rel="stylesheet">
    <style>
        .container { max-width: 400px; margin: 0 auto; padding: 20px; }
        .card { background: white; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); padding: 20px; }
        .input { width: 100%; padding: 12px; margin-bottom: 10px; border: 1px solid #ccc; border-radius: 8px; }
        .btn { width: 100%; padding: 12px; border-radius: 8px; background: #007BFF; color: white; font-weight: bold; }
    </style>
</head>
<body>
<div class="container">
    <div class="card">
        <h1 class="text-2xl font-bold text-gray-800 mb-4">Login</h1>
        <form action="<%= request.getContextPath() %>/api/login" method="post">
            <input type="email" name="email" class="input" placeholder="Email" required>
            <input type="password" name="password" class="input" placeholder="Password" required>
            <button type="submit" class="btn">Login</button>
        </form>
        <% String error = (String) session.getAttribute("error"); %>
        <% if (error != null) { %>
            <p class="text-red-500 mt-4"><%= error %></p>
            <% session.removeAttribute("error"); %>
        <% } %>
    </div>
</div>
</body>
</html>