DROP TABLE IF EXISTS employees_specialties;
DROP TABLE IF EXISTS operations_specialties;
DROP TABLE IF EXISTS operations_materials;
DROP TABLE IF EXISTS operations_machines;
DROP TABLE IF EXISTS accounts_accesses;
DROP TABLE IF EXISTS tasks_connections;
DROP TABLE IF EXISTS orders_tasks;

DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS operations;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS accounts;

DROP TABLE IF EXISTS accesses;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS specialties;
DROP TABLE IF EXISTS materials;
DROP TABLE IF EXISTS machines;

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;

CREATE TABLE accounts
(
    id             BIGSERIAL,
    email          VARCHAR      NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    account_status VARCHAR(30)  NOT NULL DEFAULT 'active', -- active / inactive
    PRIMARY KEY (id)
);
CREATE INDEX index_accounts_email ON accounts (email);

CREATE TABLE employees
(
    id             BIGSERIAL,
    account_id     BIGINT       NOT NULL UNIQUE,
    working_status VARCHAR(30)  NOT NULL,   -- working / on_vacation / on_business_trip
    first_name     VARCHAR(100) NOT NULL,
    second_name    VARCHAR(100) NOT NULL,
    third_name     VARCHAR(100) NOT NULL,
    phone_number   INT          NOT NULL UNIQUE,
    extra_info     JSONB        NOT NULL,   -- Любая информация
    PRIMARY KEY (id),
    FOREIGN KEY (account_id) REFERENCES accounts (id)
);
CREATE INDEX index_employees_account_id ON employees (account_id);
CREATE INDEX index_employees_phone_number ON employees (phone_number);

CREATE TABLE accesses
(
    id          BIGSERIAL,
    name        VARCHAR(30) NOT NULL UNIQUE,
    description TEXT        NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX index_accesses_name ON accesses (name);

CREATE TABLE accounts_accesses
(
    account_id BIGINT NOT NULL,
    access_id  BIGINT NOT NULL,
    PRIMARY KEY (account_id, access_id),
    FOREIGN KEY (account_id) REFERENCES accounts (id),
    FOREIGN KEY (access_id) REFERENCES accesses (id)
);

CREATE TABLE customers
(
    id           BIGSERIAL,
    first_name   VARCHAR(100) NOT NULL,
    second_name  VARCHAR(100) NOT NULL,
    third_name   VARCHAR(100) NOT NULL,
    email        VARCHAR(100) NOT NULL,
    phone_number INT          NOT NULL UNIQUE ,
    company      VARCHAR(255) DEFAULT NULL,
    extra_info   JSONB, -- Любая информация о заказчике (ссылки, номера, почты)
    PRIMARY KEY (id)
);
CREATE INDEX index_customers_phone_number ON customers (phone_number);

CREATE TABLE specialties -- Специальности (нужны для выполнения заданий)
(
    id             BIGSERIAL    NOT NULL,
    specialty_name VARCHAR(100) NOT NULL UNIQUE,
    PRIMARY KEY (id)
);
CREATE INDEX index_specialties_specialty_name ON specialties (specialty_name);

CREATE TABLE employees_specialties
(
    employee_id  BIGINT REFERENCES employees (id),
    specialty_id BIGINT REFERENCES specialties (id),
    PRIMARY KEY (employee_id, specialty_id),
    FOREIGN KEY (employee_id) REFERENCES employees (id),
    FOREIGN KEY (specialty_id) REFERENCES specialties (id)
);

CREATE TABLE operations -- Действия
(
    id               BIGSERIAL    NOT NULL,
    name   VARCHAR(100) NOT NULL UNIQUE,
    duration_minutes INT          NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX index_operations_name ON operations (name);

CREATE TABLE materials
(
    id            BIGSERIAL    NOT NULL,
    name VARCHAR(100) NOT NULL UNIQUE,
    unit          VARCHAR(50)  NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX index_materials_name ON materials (name);

CREATE TABLE machines
(
    id           BIGSERIAL    NOT NULL,
    name VARCHAR(100) NOT NULL UNIQUE,
    PRIMARY KEY (id)
);
CREATE INDEX index_machines_name ON machines (name);

CREATE TABLE operations_materials
(
    operation_id BIGINT NOT NULL,
    material_id  BIGINT NOT NULL,
    PRIMARY KEY (operation_id, material_id),
    FOREIGN KEY (operation_id) REFERENCES operations (id) ON DELETE CASCADE,
    FOREIGN KEY (material_id) REFERENCES materials (id) ON DELETE CASCADE
);

CREATE TABLE operations_specialties
(
    operation_id BIGINT NOT NULL,
    specialty_id BIGINT NOT NULL,
    PRIMARY KEY (operation_id, specialty_id),
    FOREIGN KEY (operation_id) REFERENCES operations (id) ON DELETE CASCADE,
    FOREIGN KEY (specialty_id) REFERENCES specialties (id) ON DELETE CASCADE
);

CREATE TABLE operations_machines
(
    operation_id BIGINT NOT NULL,
    machine_id   BIGINT NOT NULL,
    PRIMARY KEY (operation_id, machine_id),
    FOREIGN KEY (operation_id) REFERENCES operations (id) ON DELETE CASCADE,
    FOREIGN KEY (machine_id) REFERENCES machines (id) ON DELETE CASCADE
);

CREATE TABLE orders
(
    id              BIGSERIAL    NOT NULL,
    order_name      VARCHAR(255) NOT NULL,
    status          VARCHAR(30)  NOT NULL, -- open / in_progress / done / archived / hold /declined
    customer_id     BIGINT       NOT NULL,
    line_manager_id BIGINT       NOT NULL,
    description     TEXT         NOT NULL,
    begin_at        TIMESTAMP(0) NOT NULL,
    end_at          TIMESTAMP(0) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
    FOREIGN KEY (line_manager_id) REFERENCES employees (id) ON DELETE CASCADE
);
ALTER TABLE orders
    ADD COLUMN fulltext_document tsvector
        GENERATED ALWAYS AS (
            to_tsvector('russian'::regconfig,
                        order_name
                            || ' ' || description
                            || ' ' || status
            )) STORED;

CREATE INDEX index_order_status ON orders USING GIN (status);
CREATE INDEX index_orders_customer_id ON orders (customer_id);
CREATE INDEX index_orders_line_manager_id ON orders (line_manager_id);
CREATE INDEX index_fulltext_document ON orders USING GIN (fulltext_document);


CREATE TABLE tasks
(
    id           BIGSERIAL    NOT NULL,
    task_name    VARCHAR(255) NOT NULL,
    status       VARCHAR(30)  NOT NULL, -- open / in_progress / done / archived / hold / declined
    description  TEXT         NOT NULL,
    extra_info   JSONB,                 -- Любая информация о задаче
    operation_id BIGINT,
    executor_id  BIGINT,
    begin_at     TIMESTAMP(0) NOT NULL,
    end_at       TIMESTAMP(0) NOT NULL,
    order_id     BIGINT       NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (operation_id) REFERENCES operations (id) ON DELETE CASCADE,
    FOREIGN KEY (executor_id) REFERENCES employees (id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
);
CREATE INDEX index_tasks_operation_id ON tasks (operation_id);
CREATE INDEX index_tasks_executor_id ON tasks (executor_id);
CREATE INDEX index_tasks_order_id ON tasks (order_id);

CREATE TABLE orders_tasks
(
    order_id BIGINT NOT NULL,
    task_id  BIGINT NOT NULL,
    PRIMARY KEY (order_id, task_id),
    FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
);

CREATE TABLE tasks_connections
(
    task_master_id  BIGINT NOT NULL,
    task_slave_id   BIGINT NOT NULL,
    connection_type VARCHAR(30), -- subtask_on / relates_to
    PRIMARY KEY (task_master_id, task_slave_id),
    FOREIGN KEY (task_master_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (task_slave_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CHECK (task_master_id != task_slave_id)
);

------------------------------------------------------------------------------------------------------------

ALTER TABLE accounts
    ADD CONSTRAINT check_account_status CHECK (account_status IN ('active', 'inactive'));
ALTER TABLE employees
    ADD CONSTRAINT check_status CHECK (employees.working_status IN ('working', 'on_vacation', 'on_business_trip'));
ALTER TABLE orders
    ADD CONSTRAINT check_order_status CHECK (status IN ('open', 'in_progress', 'done', 'archived', 'hold', 'declined'));
ALTER TABLE tasks
    ADD CONSTRAINT check_task_status CHECK (status IN ('open', 'in_progress', 'done', 'archived', 'hold', 'declined'));
