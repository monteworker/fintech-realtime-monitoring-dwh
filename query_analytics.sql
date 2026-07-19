⭐️Целевой уровень одобрений (TR одобрено) по первичным клиентам в разбивке по каналам 

SELECT 
    toStartOfHour(toDateTime(hour)) AS hour,
    sum(ident) * 1.0 / nullif(sum(total), 0) AS cr_approved_to_issue,
    max(p1) AS p1, 
    max(p5) AS p5, 
    max(p95) AS p95, 
    max(p99) AS p99
FROM (
    WITH max_time AS (SELECT max(event_date) AS t FROM fact_conversion_funnel),
    t0 AS (
        SELECT 
            if(event_date < t - INTERVAL 70 MINUTE, 'history', 'actual') AS period,
            *
        FROM fact_conversion_funnel
        CROSS JOIN max_time 
        WHERE event_date < t - INTERVAL 10 MINUTE
    ),
    t1 AS (
        SELECT 
            period, 
            hour, 
            'All' AS channel,
            sum(issued) AS ident, 
            sum(verified) AS total,
            sum(issued) * 1.0 / nullif(sum(verified), 0) AS ratio
        FROM t0 
        GROUP BY period, hour, channel
        
        UNION ALL
        
        SELECT 
            period, 
            hour, 
            if(has(['CPA','SEO','Paid Search','Target','Direct','Referral','Social'], traffic), traffic, 'Other') AS channel,
            sum(issued) AS ident, 
            sum(verified) AS total,
            sum(issued) * 1.0 / nullif(sum(verified), 0) AS ratio
        FROM t0 
        GROUP BY period, hour, traffic
    ),
    t2 AS (
        SELECT 
            channel,
            quantile(0.01)(ratio) AS p1,
            quantile(0.05)(ratio) AS p5,
            quantile(0.95)(ratio) AS p95,
            quantile(0.99)(ratio) AS p99
        FROM t1 
        WHERE period = 'history' 
        GROUP BY channel
    )
    SELECT 
        hour, 
        t1.channel, 
        p1, p5, p95, p99,
        sum(ident) AS ident, 
        sum(total) AS total
    FROM t1 
    LEFT JOIN t2 ON t1.channel = t2.channel
    GROUP BY hour, t1.channel, p1, p5, p95, p99
) AS vt
WHERE channel = 'All'
GROUP BY hour
ORDER BY cr_approved_to_issue DESC
LIMIT 10000;



⭐️Конверсия в выдачу (TR повторные клиенты) 

SELECT 
    hour,
    ratio_actual AS tr_repeated,
    ratio_p1,
    ratio_p5,
    ratio_p95,
    ratio_p99
FROM (
    WITH t1 AS (
        SELECT
            CASE WHEN created_at >= NOW() - INTERVAL '60 MINUTE' THEN 'actual' ELSE 'history' END AS period,
            DATE_TRUNC('hour', created_at + INTERVAL '3 HOURS') AS hour,
            COUNT(*) FILTER(WHERE status = 'Issued') AS ident,
            COUNT(*) AS total
        FROM requests
        WHERE created_at >= CURRENT_DATE - INTERVAL '14 DAYS'
          AND is_repeated = TRUE
          AND approved_amount IS NOT NULL
        GROUP BY 1, 2
    ),
    t2 AS (
        SELECT 
            period, 
            hour,
            SUM(ident) AS ident,
            SUM(total) AS total,
            SUM(ident) * 100.0 / NULLIF(SUM(total), 0) AS ratio
        FROM t1 
        GROUP BY 1, 2
    ),
    t3 AS (
        SELECT
            PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ratio) AS ratio_p1,
            PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY ratio) AS ratio_p5,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ratio) AS ratio_p95,
            PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ratio) AS ratio_p99
        FROM t2 
        WHERE period = 'history'
    ),
    t4 AS (
        SELECT 
            t2.hour,
            MAX(t3.ratio_p1) AS ratio_p1,
            MAX(t3.ratio_p5) AS ratio_p5,
            MAX(t3.ratio_p95) AS ratio_p95,
            MAX(t3.ratio_p99) AS ratio_p99,
            SUM(t2.ident) * 100.0 / NULLIF(SUM(t2.total), 0) AS ratio_actual
        FROM t2 
        CROSS JOIN t3 
        WHERE t2.period = 'actual'
        GROUP BY t2.hour
    )
    SELECT 
        hour, 
        ratio_actual, 
        ratio_p1, 
        ratio_p5, 
        ratio_p95, 
        ratio_p99
    FROM t4
) AS vt
ORDER BY tr_repeated DESC
LIMIT 10000;


⭐️Конверсия "Успешная заявка в Выдачу" (по каналам привлечения) 

SELECT 
    toStartOfHour(toDateTime(hour)) AS hour,
    sum(ident) * 1.0 / nullif(sum(total), 0) AS cr_success_to_issue,
    max(p1) AS p1, 
    max(p5) AS p5, 
    max(p95) AS p95, 
    max(p99) AS p99
FROM (
    WITH max_time AS (SELECT max(event_date) AS t FROM fact_conversion_funnel),
    t0 AS (
        SELECT 
            if(event_date < t - INTERVAL 70 MINUTE, 'history', 'actual') AS period,
            *
        FROM fact_conversion_funnel
        CROSS JOIN max_time 
        WHERE event_date < t - INTERVAL 10 MINUTE
    ),
    t1 AS (
        SELECT 
            period, 
            hour, 
            'All' AS channel,
            sum(issued) AS ident, 
            sum(successful_app) AS total,
            sum(issued) * 1.0 / nullif(sum(successful_app), 0) AS ratio
        FROM t0 
        GROUP BY period, hour, channel
        
        UNION ALL
        
        SELECT 
            period, 
            hour, 
            if(has(['CPA','SEO','Paid Search','Target','Direct','Referral','Social'], traffic), traffic, 'Other') AS channel,
            sum(issued) AS ident, 
            sum(successful_app) AS total,
            sum(issued) * 1.0 / nullif(sum(successful_app), 0) AS ratio
        FROM t0 
        GROUP BY period, hour, traffic
    ),
    t2 AS (
        SELECT 
            channel,
            quantile(0.01)(ratio) AS p1,
            quantile(0.05)(ratio) AS p5,
            quantile(0.95)(ratio) AS p95,
            quantile(0.99)(ratio) AS p99
        FROM t1 
        WHERE period = 'history' 
        GROUP BY channel
    )
    SELECT 
        hour, 
        t1.channel, 
        p1, p5, p95, p99,
        sum(ident) AS ident, 
        sum(total) AS total
    FROM t1 
    LEFT JOIN t2 ON t1.channel = t2.channel
    GROUP BY hour, t1.channel, p1, p5, p95, p99
) AS vt
WHERE channel = 'All'
GROUP BY hour
ORDER BY cr_success_to_issue DESC
LIMIT 10000;
