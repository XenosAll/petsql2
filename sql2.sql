WITH calendar AS (
    SELECT
        generated_date::date AS date_from_calendar
    FROM generate_series(
        DATE '2023-07-01',
        DATE '2023-07-01' + INTERVAL '119 days',
        INTERVAL '1 day'
    ) AS generated_date
),
daily_activity AS (
    SELECT
        ue.entry_at::date AS activity_date,
        COUNT(DISTINCT ue.user_id) AS daily_active_users_cnt
    FROM userentry AS ue
    JOIN users AS u
        ON u.id = ue.user_id
    WHERE u.is_blocked IS NOT TRUE
      AND ue.entry_at >= TIMESTAMP '2023-07-01 00:00:00'
      AND ue.entry_at < TIMESTAMP '2023-10-29 00:00:00'
    GROUP BY ue.entry_at::date
),
daily_sales AS (
    SELECT
        o.paid_at::date AS payment_date,
        COUNT(DISTINCT o.user_id) AS daily_buyers_cnt,
        SUM(o.amount) AS daily_revenue
    FROM orders AS o
    WHERE o.paid_at IS NOT NULL
      AND o.status IN ('paid', 'completed')
      AND o.paid_at >= TIMESTAMP '2023-07-01 00:00:00'
      AND o.paid_at < TIMESTAMP '2023-10-29 00:00:00'
    GROUP BY o.paid_at::date
),
daily_metrics AS (
    SELECT
        c.date_from_calendar,
        COALESCE(a.daily_active_users_cnt, 0) AS daily_active_users_cnt,
        COALESCE(s.daily_buyers_cnt, 0) AS daily_buyers_cnt,
        COALESCE(s.daily_revenue, 0) AS daily_revenue
    FROM calendar AS c
    LEFT JOIN daily_activity AS a
        ON a.activity_date = c.date_from_calendar
    LEFT JOIN daily_sales AS s
        ON s.payment_date = c.date_from_calendar
),
metrics_with_windows AS (
    SELECT
        date_from_calendar,
        daily_active_users_cnt,
        daily_buyers_cnt,
        daily_revenue,
        LAG(daily_active_users_cnt) OVER (
            ORDER BY date_from_calendar
        ) AS previous_day_dau_cnt,
        MAX(daily_active_users_cnt) OVER () AS max_dau_cnt
    FROM daily_metrics
)
SELECT
    date_from_calendar,
    daily_active_users_cnt,
    daily_buyers_cnt,
    daily_revenue,
    previous_day_dau_cnt,
    daily_active_users_cnt - previous_day_dau_cnt AS dau_difference,
    max_dau_cnt,
    daily_active_users_cnt - max_dau_cnt AS diff_from_max_dau,
    ROUND(
        CASE
            WHEN daily_active_users_cnt = 0 THEN 0
            ELSE daily_buyers_cnt::numeric / daily_active_users_cnt * 100
        END,
        2
    ) AS buyer_conversion_pct
FROM metrics_with_windows
ORDER BY date_from_calendar;
