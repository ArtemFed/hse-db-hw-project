INSERT INTO accounts (email, password_hash, account_status)
SELECT 'user' || id || '@example.com',
       'hashed_password' || id,
       CASE WHEN id % 2 = 0 THEN 'active' ELSE 'inactive' END
FROM generate_series(1, 1000) id;

INSERT INTO employees (account_id, working_status, first_name, second_name, third_name, phone_number, extra_info)
SELECT id,
       CASE
           WHEN id % 3 = 0 THEN 'working'
           WHEN id % 3 = 1 THEN 'on_vacation'
           ELSE 'on_business_trip' END,
       'FirstName' || id,
       'LastName' || id,
       'ThirdName' || id,
       1234567890 + id,
       '{}'
FROM generate_series(1, 1000) id;

INSERT INTO customers (first_name, second_name, third_name, email, phone_number, company, extra_info)
SELECT 'CustFirstName' || id,
       'CustLastName' || id,
       'CustThirdName' || id,
       'customer' || id || '@example.com',
       9876540 + id,
       'Company' || id,
       '{"info1": "value1", "info2": "value2"}'
FROM generate_series(1, 1000) id;

INSERT INTO materials (name, unit)
VALUES ('Wood Board', 'pieces'),
       ('Metal Frame', 'pieces'),
       ('Fabric Upholstery', 'meters'),
       ('Foam Cushion', 'pieces'),
       ('Varnish', 'liters'),
       ('Screws', 'pieces'),
       ('Leather Cover', 'square meters'),
       ('Plastic Feet', 'pieces'),
       ('Staples', 'boxes'),
       ('Paint', 'liters');

INSERT INTO operations (name, duration_minutes)
VALUES ('Cutting Wood Boards', 60),
       ('Welding Metal Frames', 45),
       ('Upholstering with Fabric', 90),
       ('Assembling Cushions', 30),
       ('Applying Varnish', 75),
       ('Screwing Components', 40),
       ('Adding Leather Cover', 60),
       ('Attaching Plastic Feet', 20),
       ('Stapling Upholstery', 50),
       ('Painting', 80);

INSERT INTO specialties (specialty_name)
VALUES ('Carpenter'),
       ('Welder'),
       ('Upholsterer'),
       ('Assembler'),
       ('Finisher'),
       ('Screw Operator'),
       ('Leatherworker'),
       ('Plastic Technician'),
       ('Staple Operator'),
       ('Painter');

INSERT INTO equipments (name)
VALUES ('Circular Saw'),
       ('Welding Machine'),
       ('Upholstery Sewing Machine'),
       ('Cushion Assembling Machine'),
       ('Varnishing Booth'),
       ('Screwing Machine'),
       ('Leather Cutting Machine'),
       ('Plastic Molding Machine'),
       ('Stapling Machine'),
       ('Painting Booth');

INSERT INTO accesses (name, description)
VALUES ('Admin', 'Full administrative access'),
       ('Manager', 'Access to managerial functions'),
       ('Worker', 'Basic worker access');

INSERT INTO accounts_accesses (account_id, access_id)
SELECT a.id,
       (CASE
            WHEN a.id % 3 = 0 THEN 1
            WHEN a.id % 3 = 1 THEN 2
            ELSE 3 END)
FROM accounts a
LIMIT 10;

INSERT INTO employees_specialties (employee_id, specialty_id)
SELECT e.id,
       (CASE
            WHEN e.id % 3 = 0 THEN 1
            WHEN e.id % 3 = 1 THEN 2
            ELSE 3 END)
FROM employees e
LIMIT 10;

INSERT INTO operations_materials (operation_id, material_id)
SELECT o.id,
       (CASE
            WHEN o.id % 3 = 0 THEN 1
            WHEN o.id % 3 = 1 THEN 2
            ELSE 3 END)
FROM operations o
LIMIT 10;

INSERT INTO operations_specialties (operation_id, specialty_id)
SELECT o.id,
       (CASE
            WHEN o.id % 3 = 0 THEN 1
            WHEN o.id % 3 = 1 THEN 2
            ELSE 3 END)
FROM operations o
LIMIT 10;

INSERT INTO operations_equipments (operation_id, equipment_id)
SELECT o.id,
       (CASE
            WHEN o.id % 3 = 0 THEN 1
            WHEN o.id % 3 = 1 THEN 2
            ELSE 3 END)
FROM operations o
LIMIT 10;

INSERT INTO orders (order_name, status, customer_id, line_manager_id, description, begin_at, end_at)
SELECT 'Order' || id,
       (CASE
            WHEN id % 4 = 0 THEN 'archived'
            WHEN id % 4 = 1 THEN 'done'
            WHEN id % 4 = 2 THEN 'in_progress'
            ELSE 'open' END),
       (id % 100) + 1,  -- Assuming you have at least 100 customers
       (id % 1000) + 1, -- Assuming you have at least 1000 employees
       'Description for Order ' || id,
       CURRENT_TIMESTAMP,
       CURRENT_TIMESTAMP + interval '30 days'
FROM generate_series(1, 1000) id;

INSERT INTO tasks (task_name, status, description, extra_info, operation_id, executor_id, begin_at, end_at, order_id)
SELECT 'Task' || id,
       (CASE
            WHEN id % 6 = 0 THEN 'archived'
            WHEN id % 6 = 1 THEN 'done'
            WHEN id % 6 = 2 THEN 'in_progress'
            WHEN id % 6 = 3 THEN 'hold'
            ELSE 'open' END),
       'Description for Task ' || id,
       '{"info1": "value1", "info2": "value2"}',
       (id % 10) + 1,
       (id % 1000) + 1,
       CURRENT_TIMESTAMP,
       CURRENT_TIMESTAMP + interval '15 days',
       (id % 1000) + 1
FROM generate_series(1, 5000) id; -- 5 tasks per order

INSERT INTO orders_tasks (order_id, task_id)
SELECT (id % 1000) + 1,
       id
FROM generate_series(1, 5000) id; -- 5 tasks per order
