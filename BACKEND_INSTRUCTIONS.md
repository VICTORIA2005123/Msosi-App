# Backend API Reference (PHP/MySQL)

This document provides the expected SQL schema and PHP API response samples for the Campus Food Chatbot Ordering System.

## Database Schema (MySQL)

```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    is_admin BOOLEAN DEFAULT FALSE
);

CREATE TABLE restaurants (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    opening_hours VARCHAR(255) NOT NULL
);

CREATE TABLE menu (
    id INT AUTO_INCREMENT PRIMARY KEY,
    restaurant_id INT,
    item_name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    available TINYINT(1) DEFAULT 1,
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(id)
);

CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    restaurant_id INT,
    total_price DECIMAL(10, 2) NOT NULL,
    status ENUM('Pending', 'Preparing', 'Ready', 'Completed') DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(id)
);

CREATE TABLE order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    menu_id INT,
    quantity INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (menu_id) REFERENCES menu(id)
);
```

## API Endpoint Reference

### GET /restaurants
**Response:**
```json
[
  {
    "id": 1,
    "name": "Campus Diner",
    "location": "Central Plaza",
    "opening_hours": "08:00 - 20:00"
  },
  {
    "id": 2,
    "name": "Pizza Hub",
    "location": "Student Center",
    "opening_hours": "10:00 - 22:00"
  }
]
```

### GET /menu/{restaurant_id}
**Response:**
```json
[
  {
    "id": 1,
    "restaurant_id": 1,
    "item_name": "Veggie Burger",
    "price": 5.50,
    "available": 1
  },
  {
    "id": 2,
    "restaurant_id": 1,
    "item_name": "Chicken Wrap",
    "price": 6.00,
    "available": 0
  }
]
```

### POST /order
**Request Body:**
```json
{
  "user_id": 1,
  "restaurant_id": 1,
  "total_price": 11.50,
  "items": [
    {"menu_id": 1, "quantity": 1, "price": 5.50},
    {"menu_id": 3, "quantity": 1, "price": 6.00}
  ]
}
```

## Setup Instructions
1. Host these PHP scripts on your server.
2. Update `lib/services/api_service.dart` and `lib/services/auth_service.dart` with your actual server URL.
3. Ensure the PHP scripts return JSON headers: `header('Content-Type: application/json');`.
