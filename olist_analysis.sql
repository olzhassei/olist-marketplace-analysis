-- ============================================
-- АНАЛИЗ МАРКЕТПЛЕЙСА OLIST
-- Автор: Сейлхан Олжас
-- Инструменты: PostgreSQL, Tableau
-- Датасет: Brazilian E-Commerce (Olist) - Kaggle, https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
-- Период: Сен 2016 - Авг 2018
-- ============================================


-- ============================================
-- 1. АНАЛИЗ ВЫРУЧКИ
-- ============================================

-- 1.1 Общая выручка
SELECT ROUND(SUM(oi.price)::numeric, 2) AS total_revenue
FROM olist_order_items oi
         JOIN olist_orders oo ON oi.order_id = oo.order_id
WHERE oo.order_status = 'delivered'
  AND oo.order_delivered_customer_date IS NOT NULL;


-- 1.2 Ежемесячная динамика выручки
SELECT
    DATE_TRUNC('month', oo.order_purchase_timestamp::timestamp) AS month,
    ROUND(SUM(oi.price)::numeric, 2) AS monthly_revenue,
    COUNT(DISTINCT oo.order_id) AS total_orders
FROM olist_order_items oi
         JOIN olist_orders oo ON oi.order_id = oo.order_id
WHERE oo.order_status = 'delivered'
  AND oo.order_delivered_customer_date IS NOT NULL
  AND oo.order_purchase_timestamp::timestamp >= '2017-01-01'
GROUP BY month
ORDER BY month;


-- 1.3 Средний чек заказа
WITH order_totals AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS order_total
    FROM olist_order_items oi
             JOIN olist_orders oo ON oi.order_id = oo.order_id
    WHERE oo.order_status = 'delivered'
      AND oo.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.order_id
)
SELECT ROUND(AVG(order_total)::numeric, 2) AS avg_order_value
FROM order_totals;


-- ============================================
-- 2. АНАЛИЗ ПРОДАВЦОВ
-- ============================================

-- 2.1 Топ-10 продавцов по выручке
SELECT
    os.seller_id,
    os.seller_state,
    ROUND(SUM(oi.price)::numeric, 2) AS revenue
FROM olist_order_items AS oi
         JOIN olist_orders AS oo USING(order_id)
         JOIN olist_sellers AS os ON oi.seller_id = os.seller_id
WHERE oo.order_status = 'delivered'
  AND oo.order_delivered_customer_date IS NOT NULL
GROUP BY os.seller_id, os.seller_state
ORDER BY revenue DESC
LIMIT 10;


-- 2.2 Топ-10 продавцов по количеству заказов
SELECT
    os.seller_id,
    os.seller_state,
    COUNT(DISTINCT oo.order_id) AS order_amount
FROM olist_order_items AS oi
         JOIN olist_orders AS oo USING(order_id)
         JOIN olist_sellers AS os ON oi.seller_id = os.seller_id
WHERE oo.order_status = 'delivered'
  AND oo.order_delivered_customer_date IS NOT NULL
GROUP BY os.seller_id, os.seller_state
ORDER BY order_amount DESC
LIMIT 10;


-- 2.3 Количество продавцов по штатам
SELECT
    seller_state,
    COUNT(seller_id) AS total_sellers
FROM olist_sellers
GROUP BY seller_state
ORDER BY total_sellers DESC;


-- ============================================
-- 3. АНАЛИЗ ПЛАТЕЖЕЙ
-- ============================================

-- 3.1 Разбивка по способам оплаты
SELECT
    payment_type,
    COUNT(*) AS order_amount,
    ROUND(SUM(payment_value)::numeric, 2) AS total_revenue
FROM olist_order_payments
         JOIN olist_orders USING(order_id)
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY payment_type
ORDER BY total_revenue DESC;


-- 3.2 Средний чек по способу оплаты
SELECT
    payment_type,
    COUNT(*) AS order_amount,
    ROUND(AVG(payment_value)::numeric, 2) AS avg_order_value
FROM olist_order_payments
         JOIN olist_orders USING(order_id)
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY payment_type
ORDER BY avg_order_value DESC;


-- 3.3 Оплата в рассрочку vs единовременная оплата
SELECT
    COUNT(*) AS total,
    CASE
        WHEN payment_installments = 1 THEN 'Единовременная оплата'
        WHEN payment_installments > 1 THEN 'Рассрочка'
        WHEN payment_installments = 0 THEN 'Без оплаты'
        ELSE 'Прочее'
        END AS payment_status
FROM olist_order_payments
         JOIN olist_orders USING(order_id)
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY payment_status
ORDER BY total DESC;


-- ============================================
-- 4. АНАЛИЗ ДОСТАВКИ
-- ============================================

-- 4.1 Среднее количество дней от покупки до доставки
SELECT
    ROUND(AVG(EXTRACT(DAY FROM (
        order_delivered_customer_date::timestamp - order_purchase_timestamp::timestamp
        )))::numeric, 1) AS avg_delivery_days
FROM olist_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- 4.2 Среднее отклонение от ожидаемой даты доставки
SELECT
    ROUND(AVG(EXTRACT(DAY FROM (
        order_delivered_customer_date::timestamp - order_estimated_delivery_date::timestamp
        )))::numeric, 1) AS avg_delay_days
FROM olist_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- 4.3 Отклонение от ожидаемой даты доставки по штатам продавца
SELECT
    s.seller_state,
    ROUND(AVG(EXTRACT(DAY FROM (
        o.order_delivered_customer_date::timestamp - o.order_estimated_delivery_date::timestamp
        )))::numeric, 1) AS avg_delay_days,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM olist_orders o
         JOIN olist_order_items oi ON o.order_id = oi.order_id
         JOIN olist_sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY s.seller_state
ORDER BY avg_delay_days DESC;


-- ============================================
-- 5. АНАЛИЗ ТОВАРОВ И КАТЕГОРИЙ
-- ============================================

-- 5.1 Топ-10 категорий по выручке
SELECT
    t.product_category_name_english,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue,
    COUNT(DISTINCT oi.order_id) AS total_orders
FROM olist_order_items oi
         JOIN olist_orders oo ON oi.order_id = oo.order_id
         JOIN olist_products p ON oi.product_id = p.product_id
         JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE oo.order_status = 'delivered'
  AND oo.order_delivered_customer_date IS NOT NULL
GROUP BY t.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 10;


-- 5.2 Топ-10 категорий по количеству заказов
SELECT
    t.product_category_name_english,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue
FROM olist_order_items oi
         JOIN olist_orders oo ON oi.order_id = oo.order_id
         JOIN olist_products p ON oi.product_id = p.product_id
         JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE oo.order_status = 'delivered'
  AND oo.order_delivered_customer_date IS NOT NULL
GROUP BY t.product_category_name_english
ORDER BY total_orders DESC
LIMIT 10;


-- ============================================
-- 6. АНАЛИЗ ПОКУПАТЕЛЕЙ
-- ============================================

-- 6.1 Общее количество уникальных покупателей
SELECT COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM olist_customers;


-- 6.2 Повторные покупатели
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM olist_customers c
             JOIN olist_orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)::numeric, 2) AS repeat_rate
FROM customer_orders;


-- 6.3 Топ-10 штатов по количеству покупателей
SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS total_customers
FROM olist_customers
GROUP BY customer_state
ORDER BY total_customers DESC
LIMIT 10;


-- ============================================
-- 7. АНАЛИЗ ОТЗЫВОВ И УДОВЛЕТВОРЁННОСТИ
-- ============================================

-- 7.1 Средняя оценка отзывов
SELECT
    ROUND(AVG(review_score)::numeric, 2) AS avg_review_score,
    COUNT(*) AS total_reviews
FROM olist_order_reviews r
         JOIN olist_orders o ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;


-- 7.2 Распределение оценок
SELECT
    review_score,
    COUNT(*) AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()::numeric, 2) AS percentage
FROM olist_order_reviews r
         JOIN olist_orders o ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY review_score
ORDER BY review_score DESC;


-- 7.3 Средняя оценка по категориям товаров
SELECT
    t.product_category_name_english,
    ROUND(AVG(r.review_score)::numeric, 2) AS avg_score,
    COUNT(*) AS total_reviews
FROM olist_order_reviews r
         JOIN olist_orders o ON r.order_id = o.order_id
         JOIN olist_order_items oi ON o.order_id = oi.order_id
         JOIN olist_products p ON oi.product_id = p.product_id
         JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY t.product_category_name_english
HAVING COUNT(*) > 100
ORDER BY avg_score DESC
LIMIT 10;

