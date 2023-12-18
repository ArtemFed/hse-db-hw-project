-- Запрос №1: Достаем инфу о заказе, менеджере и главных задачах
-- Самый оптимизированный вариант - сделать на беке два запроса к базе данных и объединить их ответы, так как мы рпазрабатываем приложение для высоконагруженных систем
-- Тестирования проводились на базе с 10 млн значений

-- Первый вариант:
-- Итоговая цена запроса 1: 23
SELECT *
FROM orders o
         JOIN employees m ON o.line_manager_id = m.id
         JOIN customers c ON o.customer_id = c.id
WHERE o.id = '1';


-- Итоговая цена запроса 2: 193 385.98
WITH selected_order_tasks AS (SELECT *,
                                     (SELECT ARRAY(SELECT task_id FROM orders_tasks WHERE order_id = '1')) as task_ids
                              FROM orders
                              WHERE orders.id = '1')
SELECT tasks.*, selected_order_tasks.order_name, selected_order_tasks.description
FROM tasks,
     selected_order_tasks
WHERE tasks.id = ANY (selected_order_tasks.task_ids);
-- Общая итоговая цена: 193 400


-- Второй вариант:
WITH selected_order AS (SELECT *, (SELECT ARRAY(SELECT task_id FROM orders_tasks WHERE order_id = '1')) as task_ids
                        FROM orders
                        WHERE orders.id = '1')
SELECT tasks.*, selected_order.*
FROM tasks,
     selected_order
WHERE tasks.id = ANY (selected_order.task_ids);
-- Итоговая цена запроса: 386 800


-- Третий вариант с JOIN:
SELECT o.*,
       t.*
FROM orders AS o
         JOIN orders_tasks AS ot ON o.id = ot.order_id
         JOIN tasks AS t ON ot.task_id = t.id
WHERE o.id = 1;
-- Итоговая цена запроса: 1 062 803.91


-----------------------------------------------------------------------------------------------------------------------

-- Запрос №2: Получаем отчёт-статистику о каждом работнике и о выполненных им количестве задач

WITH tasks_counts AS (SELECT t.executor_id                                        AS employee_id,
                             COUNT(t.id)                                          AS total_tasks,
                             COUNT(CASE WHEN t.status = 'done' THEN 1 END)        AS tasks_done,
                             COUNT(CASE WHEN t.status = 'in_progress' THEN 1 END) AS tasks_in_progress,
                             COUNT(CASE WHEN t.status = 'planned' THEN 1 END)     AS tasks_open
                      FROM tasks AS t
                      WHERE t.begin_at >= '1999-01-08'
                        AND t.end_at <= '3000-01-08'
                      GROUP BY t.executor_id)
SELECT e.id                              AS employee_id,
       e.email,
       e.first_name,
       e.second_name,
       e.third_name,
       e.phone_number,
       COALESCE(tc.total_tasks, 0)       AS total_tasks,
       COALESCE(tc.tasks_done, 0)        AS tasks_done,
       COALESCE(tc.tasks_in_progress, 0) AS tasks_in_progress,
       COALESCE(tc.tasks_open, 0)        AS tasks_open
FROM employees e
         JOIN accounts a on a.id = e.account_id
         LEFT JOIN tasks_counts tc ON e.id = tc.employee_id
WHERE a.account_status = 'active';

-- Итоговая цена запроса: 353245.65

-----------------------------------------------------------------------------------------------------------------------

-- Запрос №3: Узнать примерное время окончания работ над заказом

SELECT MAX(t.end_at)
FROM tasks t
WHERE t.order_id = '1';

-- Итоговая цена запроса: 263250.24

-----------------------------------------------------------------------------------------------------------------------

-- Запрос №4:
-- Как мы помним мы добавили атрибут fulltext_document типа tsvector (text search vector,
-- по сути наш токенизированный документ), содержайщий инетресубщие нас поля для поиска заказов.
-- Данный атрирбут нужен нам как раз для реализации качественного текстового поиска:
SELECT *
FROM orders
WHERE fulltext_document @@ to_tsquery('russian', 'search_query')
  AND begin_at < '2038-01-19 03:14:07.499999'
LIMIT 50;
-- Как мы видим, мы токенизируем наш поисковой запрос, чтобы вывести соотвествубщие ему документы.
-- Также, разумеется не забудем добавить пагинацию не используя OFFSET, так как как известно
-- он сильно замедляет запросы на больших данных. Пагинация будет по begin_at.


-----------------------------------------------------------------------------------------------------------------------

-- Запрос №5:

-- Мы также сделали таблицу связей у задач,
-- покажем простой запрос как как с ней можно работать рекурсивно
-- ** Выпишем таблицу дистанций до всех подзадач задачи с id = 1.
WITH RECURSIVE TaskHierarchy AS (
--  base member, изначально дистанция начинается с нуля
    SELECT task_master_id, task_slave_id, 0 AS dist
    FROM tasks_connections
    WHERE task_master_id = '1'

    UNION ALL

--  recursive query
    SELECT tc.task_master_id, tc.task_slave_id, th.dist + 1
    FROM tasks_connections tc
             INNER JOIN TaskHierarchy th ON tc.task_master_id = th.task_slave_id
        AND connection_type = 'subtask_on')
-- Result form UNION ALL(R0, R1, R2, R3 ...)
SELECT task_master_id, dist
FROM TaskHierarchy
ORDER BY dist;


-----------------------------------------------------------------------------------------------------------------------

-- Запрос №6:

-- Шаг 0: Стартуем транзакцию
BEGIN;

-- Шаг 1: Создание заказа
INSERT INTO orders (order_name, status, customer_id, line_manager_id, description, begin_at, end_at)
VALUES ('Новый заказ', 'open', 1, 2, 'Описание заказа', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '7 days')
RETURNING id
INTO @order_id;

-- Шаг 2: Создание трех задач для заказа
INSERT INTO tasks (task_name, status, description, extra_info, operation_id, executor_id, begin_at, end_at, order_id)
VALUES ('Задача 1', 'open', 'Описание задачи 1', '{"key": "value1"}', 1, 3, CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP + INTERVAL '3 days', @order_id),
       ('Задача 2', 'open', 'Описание задачи 2', '{"key": "value2"}', 2, 4, CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP + INTERVAL '5 days', @order_id),
       ('Задача 3', 'open', 'Описание задачи 3', '{"key": "value3"}', 3, 5, CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP + INTERVAL '7 days', @order_id)
RETURNING id
INTO @task1_id, @task2_id, @task3_id;

-- Шаг 3: Создание связи между задачами
INSERT INTO tasks_connections (task_master_id, task_slave_id, connection_type)
VALUES (@task2_id, @task3_id, 'subtask_on');

-- Шаг 4: Завершение транзакции
COMMIT;

